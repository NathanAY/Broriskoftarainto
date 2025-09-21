extends CanvasLayer

@onready var resume_button: Button = $Control/VBoxContainer/ResumeButton
@onready var restart_button: Button = $Control/VBoxContainer/RestartButton
@onready var window_button: Button = $Control/VBoxContainer/WindowButton
@onready var exit_button: Button = $Control/VBoxContainer/ExitButton

var window_modes := [
    Vector2i(1280, 720),
    Vector2i(1920, 1080),
    "fullscreen"
]
var current_index := 0

func _ready():
    resume_button.pressed.connect(_on_resume_pressed)
    restart_button.pressed.connect(_on_restart_pressed)
    window_button.pressed.connect(_on_window_toggle_pressed)
    exit_button.pressed.connect(_on_exit_pressed)
    _apply_window_mode()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"): # Esc by default
        toggle_pause()

func toggle_pause():
    if get_tree().paused:
        _resume_game()
    else:
        _pause_game()

func _pause_game():
    get_tree().paused = true
    visible = true

func _resume_game():
    get_tree().paused = false
    visible = false

func _on_resume_pressed():
    _resume_game()

func _on_restart_pressed():
    get_tree().paused = false
    get_tree().reload_current_scene()

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
        
        # Center the window on the screen
        var screen_size = DisplayServer.screen_get_size(0)  # primary monitor
        var new_pos = (screen_size - mode) / 2
        DisplayServer.window_set_position(Vector2i(new_pos.x, new_pos.y))
        
        window_button.text = str(mode.x) + "x" + str(mode.y)

func _on_exit_pressed():
    get_tree().quit()
