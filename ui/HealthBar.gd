extends Control

@export var event_manager: EventManager
@onready var background: ColorRect = $Background
@onready var fill: ColorRect = $Fill
@onready var label: Label = $Label


func _ready() -> void:
    event_manager.subscribe("on_health_changed", Callable(self, "update_health"))
    background.color = Color(0.2, 0.2, 0.2)  # dark gray
    fill.color = Color(1, 0, 0)  # red
    visible = false  # hidden by default

func update_health(event) -> void:
    var max_value: int = event["max_health"]
    var current_value: int = event["current_health"]
    current_value = clamp(current_value, 0, max_value)
    var ratio: float = float(current_value) / float(max_value)
    fill.size.x = background.size.x * ratio
    fill.size.y = background.size.y
    label.text = str(current_value)
    # Show only if not full
    if current_value < max_value:
        visible = true
    else:
        visible = false
