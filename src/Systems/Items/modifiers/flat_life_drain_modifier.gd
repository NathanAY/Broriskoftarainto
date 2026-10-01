extends "res://src/Systems/Items/modifiers/regen_modifier.gd"

## Declared a COST so the card tints its effect line red. The behaviour itself is
## nothing special: a negative delta on the regen base, which routes through
## `Health.apply_damage` so the drain can kill and so armor / energy shield /
## death FX all still run.
@export var health_delta: float = -2.0  # flat HP lost per tick

func _init():
    display_name = "Life Drain"
    effect_kind = EffectKind.COST

## Dynamic fragment so generated values are always shown, never stale static text.
func get_tooltip_stats() -> String:
    return "Loses %s HP every %ss" % [str(absf(health_delta)), str(interval)]

func _health_delta_per_tick(_h: Health) -> float:
    return health_delta
