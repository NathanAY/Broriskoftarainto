extends "res://src/Systems/Items/modifiers/regen_modifier.gd"

@export var heal_amount_percent: float = 0.01  # % of max HP healed per tick

func _init():
    display_name = "Percent Regen"

## Dynamic fragment so generated values are always shown, never stale static text.
func get_tooltip_stats() -> String:
    return "Regenerates %d%% max HP every %ss" % [int(round(heal_amount_percent * 100.0)), str(interval)]

func _heal_per_tick(h: Health) -> float:
    return h.max_health * heal_amount_percent