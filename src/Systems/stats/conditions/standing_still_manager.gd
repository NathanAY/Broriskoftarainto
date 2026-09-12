extends Node
class_name StandingStillManager

var stats: Stats = null
var last_position: Vector2
var standing_timer: float = 0.0
var holder: Node
@export var standing_threshold := 2.0  # seconds

func set_stats_reference(s: Stats) -> void:
    stats = s
    holder = stats.get_parent()
    last_position = holder.global_position

func update(delta: float) -> void:
    if not stats:
        return

    var current_pos = holder.global_position
    if current_pos.distance_to(last_position) < 0.1:
        standing_timer += delta
        stats.set_condition("standing_still_seconds", standing_timer)
        if standing_timer >= standing_threshold:
            stats.set_condition("standing_still", 1.0)
    else:
        standing_timer = 0.0
        stats.set_condition("standing_still_seconds", 0.0)
        stats.set_condition("standing_still", 0.0)

    stats.set_condition("moving", current_pos.distance_to(last_position) > 0.1)
    last_position = current_pos
