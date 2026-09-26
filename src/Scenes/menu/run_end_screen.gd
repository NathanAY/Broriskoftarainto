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
    # The tree is paused by this screen; menus use PROCESS_MODE_ALWAYS so they
    # work while paused, but the game scene does not -> unpause before leaving.
    get_tree().paused = false
    get_tree().change_scene_to_file("res://src/Scenes/menu/CharacterSelect.tscn")

func _on_exit_pressed():
    get_tree().quit()
