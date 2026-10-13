extends "res://src/Systems/Items/modifiers/regen_modifier.gd"

@export var health_delta: float = 4.0  # signed flat HP per tick; negative drains

func _init():
    display_name = "Flat Regen"

func _regen_stat_name() -> String:
    return "flat_regen_per_second"

## Flat HP per tick turned into the per-second rate the stat panel shows.
func _regen_per_second() -> float:
    return health_delta / interval

## Dynamic fragment so generated values are always shown, never stale static text.
func get_tooltip_stats() -> String:
    return "Regenerates %s HP every %ss" % [str(health_delta), str(interval)]

func _health_delta_per_tick(_h: Health) -> float:
    return health_delta
