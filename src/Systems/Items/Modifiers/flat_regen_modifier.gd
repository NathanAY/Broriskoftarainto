extends "res://src/Systems/Items/Modifiers/regen_modifier.gd"

@export var heal_amount: float = 4.0  # flat HP healed per tick

func _init():
    display_name = "Flat Regen"

## Dynamic fragment so generated values are always shown, never stale static text.
func get_tooltip_stats() -> String:
    return "Regenerates %s HP every %ss" % [str(heal_amount), str(interval)]

func _heal_per_tick(_h: Health) -> float:
    return heal_amount