extends CanvasLayer

@onready var window_button: Button = $Control/VBoxContainer/WindowButton
@onready var show_stats_button: CheckButton = $Control/VBoxContainer/ShowStats
@onready var sound_slider: HSlider = $Control/VBoxContainer/SoundSlider
@onready var music_slider: HSlider = $Control/VBoxContainer/MusicSlider
@onready var sfx_slider: HSlider = $Control/VBoxContainer/SfxSlider
@onready var back_button: Button = $Control/VBoxContainer/BackButton

var window_modes := [
    Vector2i(1280, 720),
    Vector2i(1920, 1080),
    "fullscreen"
]
var current_index := 0

func _ready():
    window_button.pressed.connect(_on_window_toggle_pressed)
    show_stats_button.pressed.connect(_apply_show_stats)
    back_button.pressed.connect(_on_back_pressed)

    sound_slider.value_changed.connect(_on_sound_volume_changed)
    music_slider.value_changed.connect(_on_music_volume_changed)
    sfx_slider.value_changed.connect(_on_sfx_volume_changed)

    # set defaults %
    sound_slider.value = 5
    music_slider.value = 100
    sfx_slider.value = 100
    _apply_sound_volume(30)
    _apply_music_volume(100)
    _apply_sfx_volume(100)

    _apply_window_mode()
    _apply_show_stats()

func _on_window_toggle_pressed():
    current_index = (current_index + 1) % window_modes.size()
    _apply_window_mode()

func _apply_window_mode():
    var mode = window_modes[current_index]
    if typeof(mode) == TYPE_STRING and mode == "fullscreen":
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
        window_button.text = "Fullscreen"
    else:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
        DisplayServer.window_set_size(mode)
        # Center on the screen the window already sits on. Centering on
        # screen_get_size(0) instead used the primary monitor and dropped the
        # screen's position offset, so every scene change that rebuilds this
        # menu (Main.tscn, PauseMenu.tscn) teleported the window to monitor 1.
        var screen_id := DisplayServer.window_get_current_screen()
        var screen_rect := Rect2i(
            DisplayServer.screen_get_position(screen_id),
            DisplayServer.screen_get_size(screen_id)
        )
        DisplayServer.window_set_position(centered_in_screen_rect(mode, screen_rect))
        window_button.text = str(mode.x) + "x" + str(mode.y)


## Top-left position that centers `window_size` inside `screen_rect`.
## Takes the rect rather than a screen id so it stays free of DisplayServer and
## can be tested against any monitor layout, including an offset one.
static func centered_in_screen_rect(window_size: Vector2i, screen_rect: Rect2i) -> Vector2i:
    var slack := screen_rect.size - window_size
    return screen_rect.position + Vector2i(int(slack.x / 2.0), int(slack.y / 2.0))

func _apply_show_stats():
    var ui_root: Node = get_parent().get_parent()
    if ui_root == null or not ui_root.has_node("CanvasLayer/CharacterUi/PanelContainer"):
        return
    var charactUI: Control = ui_root.get_node("CanvasLayer/CharacterUi/PanelContainer")
    charactUI.visible = show_stats_button.button_pressed


# ------------------ AUDIO ------------------
func _on_sound_volume_changed(value: float) -> void:
    _apply_sound_volume(value)

func _on_music_volume_changed(value: float) -> void:
    _apply_music_volume(value)

func _on_sfx_volume_changed(value: float) -> void:
    _apply_sfx_volume(value)

func _apply_sound_volume(value: float) -> void:
    var bus_idx = AudioServer.get_bus_index("Master")
    var db = linear_to_db(value / 100.0)  # 0–100 → 0.0–1.0 → dB
    AudioServer.set_bus_volume_db(bus_idx, db)

func _apply_music_volume(value: float) -> void:
    var bus_idx = AudioServer.get_bus_index("Music")
    var db = linear_to_db(value / 100.0)  # 0–100 → 0.0–1.0 → dB
    AudioServer.set_bus_volume_db(bus_idx, db)

func _apply_sfx_volume(value: float) -> void:
    var bus_idx = AudioServer.get_bus_index("SFX")
    var db = linear_to_db(value / 100.0)
    AudioServer.set_bus_volume_db(bus_idx, db)

func _on_back_pressed():
    visible = false
    get_parent().get_node("Control").visible = true
