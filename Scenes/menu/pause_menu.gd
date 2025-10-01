extends CanvasLayer

@onready var resume_button: Button = $Control/VBoxContainer/ResumeButton
@onready var restart_button: Button = $Control/VBoxContainer/RestartButton
@onready var new_run_button: Button = $Control/VBoxContainer/NewRunButton
@onready var options_button: Button = $Control/VBoxContainer/OptionsButton
@onready var exit_button: Button = $Control/VBoxContainer/ExitButton

@onready var options_menu: CanvasLayer = $OptionsMenu

var window_modes := [
    Vector2i(1280, 720),
    Vector2i(1920, 1080),
    "fullscreen"
]
var current_index := 0

func _ready():
    resume_button.pressed.connect(_on_resume_pressed)
    restart_button.pressed.connect(_on_restart_pressed)
    new_run_button.pressed.connect(_on_new_run_pressed)
    options_button.pressed.connect(_on_options_pressed)
    exit_button.pressed.connect(_on_exit_pressed)
    options_menu.visible = false

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

func _on_options_pressed():
    $Control.visible = false
    options_menu.visible = true

func _on_new_run_pressed():
    toggle_pause()
    get_tree().change_scene_to_file("res://Scenes/menu/StarterMenu.tscn")

func _on_exit_pressed():
    get_tree().quit()
