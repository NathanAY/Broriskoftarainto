extends "res://src/Systems/Items/modifiers/regen_modifier.gd"

## The percent twin of flat_life_drain_modifier.gd: see that file for why a
## negative delta is routed through `Health.apply_damage` rather than `heal()`.
@export var health_delta_percent: float = -0.01  # % of max HP lost per tick

func _init():
    display_name = "Percent Life Drain"
    effect_kind = EffectKind.COST

## Dynamic fragment so generated values are always shown, never stale static text.
func get_tooltip_stats() -> String:
    return "Loses %d%% max HP every %ss" % [int(round(absf(health_delta_percent) * 100.0)), str(interval)]

func _health_delta_per_tick(h: Health) -> float:
    return h.max_health * health_delta_percent
