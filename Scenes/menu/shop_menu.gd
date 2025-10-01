extends CanvasLayer
class_name ShopMenu

@onready var next_stage_button: Button = $Control/VBoxContainer/NextStageButton

signal next_stage_pressed

func _ready():
    visible = false
    next_stage_button.pressed.connect(_on_next_stage_pressed)

func show_menu():
    get_tree().paused = true
    visible = true

func hide_menu():
    get_tree().paused = false
    visible = false

func _on_next_stage_pressed():
    hide_menu()
    emit_signal("next_stage_pressed")
