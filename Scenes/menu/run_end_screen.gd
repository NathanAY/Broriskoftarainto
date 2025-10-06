extends CanvasLayer
class_name RunEndScreen

@onready var label: Label = $Control/VBoxContainer/Label
@onready var new_run_button: Button = $Control/VBoxContainer/NewRunButton
@onready var exit_button: Button = $Control/VBoxContainer/ExitButton


func _ready():
    new_run_button.pressed.connect(_on_new_run_pressed)
    exit_button.pressed.connect(_on_exit_pressed)
    get_tree().paused = true

func _on_new_run_pressed():
    get_tree().change_scene_to_file("res://Scenes/menu/StarterMenu.tscn")

func _on_exit_pressed():
    get_tree().quit()
