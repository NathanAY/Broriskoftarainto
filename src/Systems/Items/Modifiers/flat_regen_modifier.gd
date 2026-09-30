extends "res://src/Systems/Items/modifiers/regen_modifier.gd"

@export var health_delta: float = 4.0  # signed flat HP per tick; negative drains

func _init():
    display_name = "Flat Regen"

## Dynamic fragment so generated values are always shown, never stale static text.
func get_tooltip_stats() -> String:
    return "Regenerates %s HP every %ss" % [str(health_delta), str(interval)]

func _health_delta_per_tick(_h: Health) -> float:
    return health_delta
