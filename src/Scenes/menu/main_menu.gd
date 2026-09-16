extends CanvasLayer

@onready var new_game_button: Button = $Control/VBoxContainer/NewGameButton
@onready var options_button: Button = $Control/VBoxContainer/OptionsButton
@onready var exit_button: Button = $Control/VBoxContainer/ExitButton

@onready var main_control: Control = $Control
@onready var options_menu: CanvasLayer = $OptionsMenu


func _ready() -> void:
    new_game_button.pressed.connect(_on_new_game_pressed)
    options_button.pressed.connect(_on_options_pressed)
    exit_button.pressed.connect(_on_exit_pressed)
    options_menu.visible = false
    main_control.visible = true


func _on_new_game_pressed() -> void:
    get_tree().change_scene_to_file("res://src/Scenes/menu/CharacterSelect.tscn")


func _on_options_pressed() -> void:
    main_control.visible = false
    options_menu.visible = true


func _on_exit_pressed() -> void:
    get_tree().quit()
