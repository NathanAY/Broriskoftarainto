extends Node2D
class_name FloatingNumber

@export var lifetime: float = 0.8
@export var rise_distance: float = 30.0
@export var start_scale: float = 1.5
@export var end_scale: float = 1.0
@export var color: = Color(1, 0, 0)  # red text

@onready var label: Label = $Label

func show_damage(amount: int) -> void:
    label.text = str(amount)
    label.modulate = color
    scale = Vector2(start_scale, start_scale)

    # Animate upward, fade, and scale
    var tween := create_tween()
    tween.tween_property(self, "position:y", position.y - rise_distance, lifetime)
    tween.parallel().tween_property(self, "scale", Vector2(end_scale, end_scale), lifetime)
    tween.parallel().tween_property(label, "modulate:a", 0.0, lifetime)

    tween.finished.connect(queue_free)

func show_text(text: String) -> void:
    label.text = str(text)
    label.modulate = color
    scale = Vector2(start_scale, start_scale)

    # Animate upward, fade, and scale
    var tween := create_tween()
    tween.tween_property(self, "position:y", position.y - rise_distance, lifetime)
    tween.parallel().tween_property(self, "scale", Vector2(end_scale, end_scale), lifetime)
    tween.parallel().tween_property(label, "modulate:a", 0.0, lifetime)

    tween.finished.connect(queue_free)
