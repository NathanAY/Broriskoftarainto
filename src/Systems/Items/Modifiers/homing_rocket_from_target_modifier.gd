extends "res://src/Systems/Items/Modifiers/homing_rocket_modifier.gd"

func _init():
    display_name = "Homing Rocket From Target"
    trigger_event = "on_hit"
    modifier_meta = "spawned_by_HomingRocketFromTargetModifier"

func _on_trigger(event: Dictionary) -> void:
    if _is_own_projectile(event):
        return
    var damage: float = _extract_damage(event)
    var primary := _extract_primary(event)
    var next_target := _find_next_target(primary)
    for i in range(_active_stacks()):
        call_deferred("_spawn_homing_projectile", _spawn_source(primary), damage, next_target)

## The hit entity (target), or the damage source when the holder itself was hit.
func _extract_primary(event: Dictionary) -> Node:
    if event.has("damage_context"):
        var damage_ctx: DamageContext = event["damage_context"]
        if damage_ctx.target != holder:
            return damage_ctx.target
        if damage_ctx.source != holder:
            return damage_ctx.source
    return null

func _spawn_source(primary: Node) -> Node:
    return primary if primary else holder