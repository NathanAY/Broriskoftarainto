# GdUnit generated TestSuite
class_name GameSettingsTest
extends GdUnitTestSuite

## The regression behind this suite: options lived on `OptionsMenu`, which is
## instanced once per menu scene, so a scene change re-ran its `_ready()` and
## reset the window size and the volumes to their defaults. They now live in the
## `GameSettings` autoload.

const OPTIONS_MENU_SCENE_PATH := "res://src/Scenes/menu/OptionsMenu.tscn"

## Preloaded rather than `load()`ed so a second store is typed: `load().new()`
## is a Variant, and GDScript cannot infer a type from it.
const SETTINGS_SCRIPT := preload("res://src/Scripts/autoload/game_settings.gd")

## Scratch file, so a test run neither reads nor writes the player's real
## `user://settings.cfg`.
const SCRATCH_PATH := "user://test_game_settings.cfg"

var _saved_settings_path := ""
var _saved_bus_volumes := {}
var _saved_window_mode_index := 0


func before_test() -> void:
    _saved_settings_path = GameSettings.settings_path
    _saved_window_mode_index = GameSettings.window_mode_index
    for bus_name in ["Master", "Music", "SFX"]:
        var bus_index := AudioServer.get_bus_index(bus_name)
        if bus_index >= 0:
            _saved_bus_volumes[bus_name] = AudioServer.get_bus_volume_db(bus_index)
    GameSettings.settings_path = SCRATCH_PATH
    _remove_scratch()
    GameSettings.reset_to_defaults()


func after_test() -> void:
    GameSettings.settings_path = _saved_settings_path
    GameSettings.window_mode_index = _saved_window_mode_index
    GameSettings.apply_volumes()
    for bus_name in _saved_bus_volumes:
        AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus_name), _saved_bus_volumes[bus_name])
    _remove_scratch()
    collect_orphan_node_details()


func _remove_scratch() -> void:
    if FileAccess.file_exists(SCRATCH_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_PATH))


func _build_options_menu() -> CanvasLayer:
    var menu: CanvasLayer = load(OPTIONS_MENU_SCENE_PATH).instantiate()
    add_child(menu)
    return menu


func _free_options_menu(menu: CanvasLayer) -> void:
    if is_instance_valid(menu):
        menu.queue_free()


# ------------------ persistence across scenes ------------------


## The bug, stated directly: change the window mode, throw the menu away the way
## a scene change does, build a fresh one, and the mode is still the new one.
func test_window_mode_survives_rebuilding_the_options_menu() -> void:
    var first_menu := _build_options_menu()
    first_menu._on_window_toggle_pressed()
    var chosen_index := GameSettings.window_mode_index
    assert_int(chosen_index).override_failure_message(
        "the toggle should have advanced off the default mode"
    ).is_equal(1)
    _free_options_menu(first_menu)

    var second_menu := _build_options_menu()
    assert_int(GameSettings.window_mode_index).override_failure_message(
        "a rebuilt options menu must not reset the chosen window mode"
    ).is_equal(chosen_index)
    assert_str(second_menu.window_button.text).is_equal(
        GameSettings.window_mode_label()
    ).override_failure_message("the button label has to show the stored mode, not 'Window'")
    _free_options_menu(second_menu)


func test_volumes_survive_rebuilding_the_options_menu() -> void:
    var first_menu := _build_options_menu()
    first_menu._on_music_volume_changed(42.0)
    first_menu._on_sfx_volume_changed(17.0)
    _free_options_menu(first_menu)

    var second_menu := _build_options_menu()
    assert_float(second_menu.music_slider.value).override_failure_message(
        "the music slider has to come back at the stored value"
    ).is_equal(42.0)
    assert_float(second_menu.sfx_slider.value).override_failure_message(
        "the sfx slider has to come back at the stored value"
    ).is_equal(17.0)
    _free_options_menu(second_menu)


func test_show_stats_survives_rebuilding_the_options_menu() -> void:
    var first_menu := _build_options_menu()
    first_menu.show_stats_button.button_pressed = true
    first_menu._on_show_stats_toggled()
    _free_options_menu(first_menu)

    var second_menu := _build_options_menu()
    assert_bool(second_menu.show_stats_button.button_pressed).override_failure_message(
        "the show-stats toggle has to come back checked"
    ).is_true()
    _free_options_menu(second_menu)


## Reading the controls must not become writing them. `_ready` fills the sliders
## from the store, and filling a slider emits `value_changed`; if that were
## wired first, opening the menu would overwrite the stored value with the
## default it had just been handed.
func test_opening_the_menu_does_not_overwrite_stored_volumes() -> void:
    GameSettings.set_music_volume(64.0)
    GameSettings.set_sfx_volume(23.0)

    var menu := _build_options_menu()

    assert_float(GameSettings.music_volume).is_equal(64.0)
    assert_float(GameSettings.sfx_volume).is_equal(23.0)
    _free_options_menu(menu)


# ------------------ the file ------------------


func test_settings_are_written_to_the_file_immediately() -> void:
    GameSettings.set_window_mode_index(2)
    GameSettings.set_music_volume(55.0)

    var config := ConfigFile.new()
    assert_int(config.load(SCRATCH_PATH)).is_equal(OK)
    assert_int(config.get_value("options", "window_mode_index")).is_equal(2)
    assert_float(config.get_value("options", "music_volume")).is_equal(55.0)


## A fresh store pointed at the same file has to come up with the same values,
## which is what carries the options over a restart.
func test_settings_are_read_back_by_a_fresh_store() -> void:
    GameSettings.set_window_mode_index(1)
    GameSettings.set_sound_volume(70.0)
    GameSettings.set_music_volume(60.0)
    GameSettings.set_sfx_volume(50.0)
    GameSettings.set_show_stats(true)

    var store := SETTINGS_SCRIPT.new()
    store.settings_path = SCRATCH_PATH
    store.load_settings()

    assert_int(store.window_mode_index).is_equal(1)
    assert_float(store.sound_volume).is_equal(70.0)
    assert_float(store.music_volume).is_equal(60.0)
    assert_float(store.sfx_volume).is_equal(50.0)
    assert_bool(store.show_stats).is_true()
    store.free()


## A first run has no file at all, and that is not a failure.
func test_missing_file_leaves_the_defaults_alone() -> void:
    var store := SETTINGS_SCRIPT.new()
    store.settings_path = SCRATCH_PATH

    store.load_settings()

    assert_int(store.window_mode_index).is_equal(GameSettings.DEFAULT_WINDOW_MODE_INDEX)
    assert_float(store.sound_volume).is_equal(GameSettings.DEFAULT_SOUND_VOLUME)
    assert_float(store.music_volume).is_equal(GameSettings.DEFAULT_MUSIC_VOLUME)
    assert_float(store.sfx_volume).is_equal(GameSettings.DEFAULT_SFX_VOLUME)
    assert_bool(store.show_stats).is_equal(GameSettings.DEFAULT_SHOW_STATS)
    store.free()


## A hand-edited or truncated file can hold an index past the end of
## WINDOW_MODES, and reading it must not leave the menu one past the last mode.
func test_out_of_range_window_mode_index_from_the_file_is_clamped() -> void:
    var config := ConfigFile.new()
    config.set_value("options", "window_mode_index", 99)
    config.save(SCRATCH_PATH)

    GameSettings.load_settings()

    assert_int(GameSettings.window_mode_index).is_equal(GameSettings.WINDOW_MODES.size() - 1)


# ------------------ values ------------------


func test_window_mode_index_is_clamped_to_the_available_modes() -> void:
    GameSettings.set_window_mode_index(99)
    assert_int(GameSettings.window_mode_index).is_equal(GameSettings.WINDOW_MODES.size() - 1)
    GameSettings.set_window_mode_index(-5)
    assert_int(GameSettings.window_mode_index).is_equal(0)


## Cycling has to wrap, because the window button is the only way to reach the
## modes and it can never escape the list otherwise.
func test_cycling_the_window_mode_wraps_around() -> void:
    GameSettings.set_window_mode_index(GameSettings.WINDOW_MODES.size() - 1)
    GameSettings.cycle_window_mode()
    assert_int(GameSettings.window_mode_index).is_equal(0)


func test_window_mode_label_names_the_size_or_fullscreen() -> void:
    GameSettings.set_window_mode_index(1)
    assert_str(GameSettings.window_mode_label()).is_equal("1920x1080")
    GameSettings.set_window_mode_index(2)
    assert_str(GameSettings.window_mode_label()).is_equal("Fullscreen")


func test_volumes_are_clamped_to_the_slider_range() -> void:
    GameSettings.set_music_volume(400.0)
    assert_float(GameSettings.music_volume).is_equal(100.0)
    GameSettings.set_music_volume(-20.0)
    assert_float(GameSettings.music_volume).is_equal(0.0)


## The slider is 0-100 percent; the bus wants decibels. Getting this wrong is
## audible rather than crashy, so it is pinned directly.
func test_volume_percent_reaches_the_bus_in_decibels() -> void:
    GameSettings.set_music_volume(50.0)

    var music_index := AudioServer.get_bus_index("Music")
    assert_float(AudioServer.get_bus_volume_db(music_index)).is_equal_approx(
        linear_to_db(0.5), 0.001
    ).override_failure_message("half volume on the slider is half amplitude, not 50 dB")


## A slider at zero has to silence the bus. `linear_to_db(0)` is -inf, which is
## the correct answer; the mistake to avoid is special-casing it to 0 dB.
func test_zero_volume_silences_the_bus() -> void:
    GameSettings.set_music_volume(0.0)

    var music_index := AudioServer.get_bus_index("Music")
    assert_bool(is_inf(AudioServer.get_bus_volume_db(music_index))).is_true()