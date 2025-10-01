extends CanvasLayer

@onready var window_button: Button = $Control/VBoxContainer/WindowButton
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
    back_button.pressed.connect(_on_back_pressed)

    sound_slider.value_changed.connect(_on_sound_volume_changed)
    music_slider.value_changed.connect(_on_music_volume_changed)
    sfx_slider.value_changed.connect(_on_sfx_volume_changed)

    # set defaults %
    sound_slider.value = 15
    music_slider.value = 100
    sfx_slider.value = 100
    _apply_sound_volume(15)
    _apply_music_volume(100)
    _apply_sfx_volume(100)

    _apply_window_mode()

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
        var screen_size = DisplayServer.screen_get_size(0)
        var new_pos = (screen_size - mode) / 2
        DisplayServer.window_set_position(Vector2i(new_pos.x, new_pos.y))
        window_button.text = str(mode.x) + "x" + str(mode.y)


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
