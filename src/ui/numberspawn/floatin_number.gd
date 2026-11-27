extends Node2D
class_name FloatingNumber

const DECIMAL_BELOW: float = 10.0  # damage under this shows one decimal
const CRIT_SCALE: float = 1.6  # size multiplier for a crit number

@export var lifetime: float = 0.8
@export var rise_distance: float = 30.0
@export var start_scale: float = 1.5
@export var end_scale: float = 1.0
@export var color: = Color(1, 0, 0)  # red text

@onready var label: Label = $Label

## Damage below `decimal_below` shows one decimal (`3.2`); bigger hits show whole
## numbers. A crit gets a `!` and is drawn `crit_scale` times larger.
func show_damage(amount: float, crit: bool = false) -> void:
    var text := ("%.1f" % amount).trim_suffix(".0") if absf(amount) < DECIMAL_BELOW else str(int(amount))
    if crit:
        _play(text + "!", CRIT_SCALE)
    else:
        _play(text, 1.0)

func show_text(text: String) -> void:
    _play(text, 1.0)

func _play(text: String, size_mult: float) -> void:
    label.text = text
    label.modulate = color
    scale = Vector2.ONE * start_scale * size_mult

    # Animate upward, fade, and scale
    var tween := create_tween()
    tween.tween_property(self, "position:y", position.y - rise_distance, lifetime)
    tween.parallel().tween_property(self, "scale", Vector2.ONE * end_scale * size_mult, lifetime)
    tween.parallel().tween_property(label, "modulate:a", 0.0, lifetime)

    tween.finished.connect(queue_free)
