extends Node

## Player options that have to outlive the scene they were changed in.
##
## `OptionsMenu` is instanced inside every menu scene (`Main.tscn`,
## `PauseMenu.tscn`), so any state kept on that node died with the scene it
## lived in: changing the window size or a volume and then changing scene re-ran
## `OptionsMenu._ready()`, which reset every control to its defaults. The values
## live here instead, in an autoload, and are mirrored to `user://settings.cfg`
## so they also survive a restart.
##
## Setters are methods rather than property setters on purpose. A property
## setter would fire while `load_settings()` is still reading the file, and
## writing back on every line of a load is how a half-written file happens.

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "options"

## The window modes the options button cycles through, in button order. The
## string marks fullscreen; anything else is a `Vector2i` window size.
const FULLSCREEN := "fullscreen"
const WINDOW_MODES: Array = [Vector2i(1280, 720), Vector2i(1920, 1080), FULLSCREEN]

const DEFAULT_WINDOW_MODE_INDEX := 0
const DEFAULT_SOUND_VOLUME := 30.0
const DEFAULT_MUSIC_VOLUME := 100.0
const DEFAULT_SFX_VOLUME := 100.0
const DEFAULT_SHOW_STATS := false

## Overridable so a test can point the store at a scratch file instead of the
## player's real settings. See `test/Systems/menu/test_game_settings.gd`.
var settings_path: String = SETTINGS_PATH

var window_mode_index: int = DEFAULT_WINDOW_MODE_INDEX
var sound_volume: float = DEFAULT_SOUND_VOLUME
var music_volume: float = DEFAULT_MUSIC_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME
var show_stats: bool = DEFAULT_SHOW_STATS


func _ready() -> void:
    load_settings()
    # Volumes only, not the window mode: the window is configured by whichever
    # menu is on screen, and doing it from an autoload would fight the window
    # the engine has just set up.
    apply_volumes()


## Restores every option to its shipped default, applies them and saves. The
## file is left alone when there is nothing to reset away from.
func reset_to_defaults() -> void:
    window_mode_index = DEFAULT_WINDOW_MODE_INDEX
    sound_volume = DEFAULT_SOUND_VOLUME
    music_volume = DEFAULT_MUSIC_VOLUME
    sfx_volume = DEFAULT_SFX_VOLUME
    show_stats = DEFAULT_SHOW_STATS
    save_settings()
    apply_volumes()


# ------------------ window ------------------


## The `Vector2i` size or `FULLSCREEN` for the current mode.
func window_mode() -> Variant:
    return WINDOW_MODES[window_mode_index]


## `WINDOW_MODES` holds `Vector2i` sizes and one `FULLSCREEN` string, so this is
## a type test rather than a comparison - `==` against a string errors when the
## mode is a `Vector2i`.
func is_fullscreen() -> bool:
    return window_mode() is String


## Advances to the next mode, which is what the window button does.
func cycle_window_mode() -> void:
    set_window_mode_index((window_mode_index + 1) % WINDOW_MODES.size())


func set_window_mode_index(index: int) -> void:
    window_mode_index = clampi(index, 0, WINDOW_MODES.size() - 1)
    save_settings()
    apply_window_mode()


## Pushes the current mode onto the real window. Called whenever the mode
## changes and by every `OptionsMenu` as it opens, because a scene change can
## rebuild the window under us.
func apply_window_mode() -> void:
    var mode: Variant = window_mode()
    if is_fullscreen():
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
        return
    var window_size: Vector2i = mode
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
    DisplayServer.window_set_size(window_size)
    # Center on the screen the window already sits on. Centering on
    # screen_get_size(0) instead used the primary monitor and dropped the
    # screen's position offset, so every scene change that rebuilds this
    # menu (Main.tscn, PauseMenu.tscn) teleported the window to monitor 1.
    var screen_id := DisplayServer.window_get_current_screen()
    var screen_rect := Rect2i(
        DisplayServer.screen_get_position(screen_id),
        DisplayServer.screen_get_size(screen_id)
    )
    DisplayServer.window_set_position(centered_in_screen_rect(window_size, screen_rect))


## Top-left position that centers `window_size` inside `screen_rect`.
## Takes the rect rather than a screen id so it stays free of DisplayServer and
## can be tested against any monitor layout, including an offset one.
static func centered_in_screen_rect(window_size: Vector2i, screen_rect: Rect2i) -> Vector2i:
    var slack := screen_rect.size - window_size
    return screen_rect.position + Vector2i(int(slack.x / 2.0), int(slack.y / 2.0))


## Label for the window button: the size, or "Fullscreen".
func window_mode_label() -> String:
    if is_fullscreen():
        return "Fullscreen"
    var window_size: Vector2i = window_mode()
    return str(window_size.x) + "x" + str(window_size.y)


# ------------------ audio ------------------


func set_sound_volume(percent: float) -> void:
    sound_volume = _clamp_percent(percent)
    save_settings()
    apply_bus_volume("Master", sound_volume)


func set_music_volume(percent: float) -> void:
    music_volume = _clamp_percent(percent)
    save_settings()
    apply_bus_volume("Music", music_volume)


func set_sfx_volume(percent: float) -> void:
    sfx_volume = _clamp_percent(percent)
    save_settings()
    apply_bus_volume("SFX", sfx_volume)


## Applies all three stored volumes to their buses.
func apply_volumes() -> void:
    apply_bus_volume("Master", sound_volume)
    apply_bus_volume("Music", music_volume)
    apply_bus_volume("SFX", sfx_volume)


## 0-100 percent onto an audio bus. A missing bus is a project setup problem,
## not something to crash a menu over, so it warns and moves on.
func apply_bus_volume(bus_name: String, percent: float) -> void:
    var bus_index := AudioServer.get_bus_index(bus_name)
    if bus_index < 0:
        push_warning("GameSettings: no audio bus named %s" % bus_name)
        return
    AudioServer.set_bus_volume_db(bus_index, percent_to_db(percent))


## 0-100 percent to decibels. `linear_to_db(0)` is -inf, which is the correct
## reading of "the slider is at zero" - the bus is silent, not at 0 dB.
func percent_to_db(percent: float) -> float:
    return linear_to_db(clampf(percent, 0.0, 100.0) / 100.0)


static func _clamp_percent(percent: float) -> float:
    return clampf(percent, 0.0, 100.0)


# ------------------ show stats ------------------


func set_show_stats(visible_on_screen: bool) -> void:
    show_stats = visible_on_screen
    save_settings()


# ------------------ persistence ------------------


## Writes the current values to `settings_path`. Every setter calls this, so a
## setting is on disk the moment it changes rather than at some later flush.
func save_settings() -> void:
    var config := ConfigFile.new()
    config.set_value(SETTINGS_SECTION, "window_mode_index", window_mode_index)
    config.set_value(SETTINGS_SECTION, "sound_volume", sound_volume)
    config.set_value(SETTINGS_SECTION, "music_volume", music_volume)
    config.set_value(SETTINGS_SECTION, "sfx_volume", sfx_volume)
    config.set_value(SETTINGS_SECTION, "show_stats", show_stats)
    var error := config.save(settings_path)
    if error != OK:
        push_warning("GameSettings: could not save %s (error %d)" % [settings_path, error])


## Reads `settings_path` back over the current values, keeping the defaults for
## anything missing. A file that does not exist is the first-run case, not an
## error, so it is silent; an unreadable one warns.
func load_settings() -> void:
    if not FileAccess.file_exists(settings_path):
        return
    var config := ConfigFile.new()
    var error := config.load(settings_path)
    if error != OK:
        push_warning("GameSettings: could not load %s (error %d)" % [settings_path, error])
        return
    window_mode_index = clampi(
        int(config.get_value(SETTINGS_SECTION, "window_mode_index", DEFAULT_WINDOW_MODE_INDEX)),
        0,
        WINDOW_MODES.size() - 1
    )
    sound_volume = _clamp_percent(
        float(config.get_value(SETTINGS_SECTION, "sound_volume", DEFAULT_SOUND_VOLUME))
    )
    music_volume = _clamp_percent(
        float(config.get_value(SETTINGS_SECTION, "music_volume", DEFAULT_MUSIC_VOLUME))
    )
    sfx_volume = _clamp_percent(
        float(config.get_value(SETTINGS_SECTION, "sfx_volume", DEFAULT_SFX_VOLUME))
    )
    show_stats = bool(config.get_value(SETTINGS_SECTION, "show_stats", DEFAULT_SHOW_STATS))