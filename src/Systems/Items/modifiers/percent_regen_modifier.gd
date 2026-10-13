extends "res://src/Systems/Items/modifiers/regen_modifier.gd"

@export var health_delta_percent: float = 0.01  # signed % of max HP per tick; negative drains

func _init():
    display_name = "Percent Regen"

func _regen_stat_name() -> String:
    return "percent_regen_per_second"

## The export is a fraction per tick; the stat is percentage points per second,
## the same 0-100 convention `critical_chance` uses.
func _regen_per_second() -> float:
    return health_delta_percent / interval * 100.0

## Dynamic fragment so generated values are always shown, never stale static text.
func get_tooltip_stats() -> String:
    return "Regenerates %d%% max HP every %ss" % [int(round(health_delta_percent * 100.0)), str(interval)]

func _health_delta_per_tick(h: Health) -> float:
    return h.max_health * health_delta_percent
