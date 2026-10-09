# res://src/scripts/weapons/AreaWeapon.gd
#
# A weapon that damages *everything* in range rather than one picked target.
#
# The behaviour is entirely the target selector's, but the range it is given is
# not: `BaseWeapon._on_timeout` measures with the full `weapon_range`, so
# `try_shoot` re-queries the selector with `radius` below. Halving only the burst
# visual would leave the damage reaching twice as far as the circle the player is
# shown. With `AllTargetsInRangeSelector` that is every `damageable` node within
# `radius` (half of `weapon_range`) of this weapon's own `sprite_node`.
# Combined with the sprite orbiting the holder at `weapon_orbit_radius`, that
# reads as an aura centred on the wielder - there is no impact point and no
# chosen target.
#
# Because the sprite is the origin of that measurement, the burst visual is
# placed there too, so what the player sees is exactly what was damaged.
extends BaseWeapon
class_name AreaWeapon

const BURST_SCENE := preload("res://src/Scenes/particles/area_damage_burst.tscn")

## The aura's damage radius in **meters**: half of `weapon_range`. A getter
## rather than an export, so the number the damage is measured against and the
## number the player is shown cannot disagree.
var radius: float:
    get:
        return weapon_range * 0.5

## The same radius in pixels, which is what the target selector measures against
## and what the burst visual is scaled to.
func get_radius_px() -> float:
    return get_range_px() * 0.5

## `_targets` is what `_on_timeout` found using the full `weapon_range`, and is
## unused: the aura's own range is narrower, so the list is re-derived rather
## than trusted. Underscored rather than merely tolerated, because the
## parameter really is dead on this path.
func try_shoot(_targets: Array[Node]) -> void:
    var holder = get_holder()
    if not holder: return
    var effective_targets := target_selector.find_targets(sprite_node, get_radius_px(), holder)
    _spawn_burst(holder)
    for t in effective_targets:
        if t.has_node("Health"):
            do_damage(t)

## The pulse visual for this tick.
##
## Parented to the holder rather than to the weapon, because a weapon is a
## `Resource` and has no place in the tree; the holder is also what
## `remove_from` frees, so nothing is left behind when the weapon is unequipped.
## `local_coords` is off on both emitters, so the shards stay where they were
## thrown instead of being dragged along by a moving holder.
func _spawn_burst(holder: Node) -> void:
    var burst: AreaDamageBurst = BURST_SCENE.instantiate()
    burst.radius = get_radius_px()
    holder.add_child(burst)
    # After parenting, not before: an unparented Node2D has no parent transform
    # to compose, so writing `global_position` first would store the sprite's
    # world position as a *local* one and land the burst one holder-offset away.
    # `_ready` reads `radius`, so that has to be set before `add_child`.
    if sprite_node and is_instance_valid(sprite_node):
        burst.global_position = sprite_node.global_position

func do_damage(body):
    var ctx = DamageContext.new()
    ctx.source = get_holder()
    ctx.target = body
    ctx.base_amount = current_damage
    ctx.final_amount = current_damage
    ctx.tags.append("melee")
    if event_manager: 
        event_manager.emit_event("before_deal_damage", {"damage_context": ctx})
    var bodyHealth: Health = body.get_node("Health")
    if not bodyHealth.apply_damage(ctx):
        return  # already dead: the hit does not land, so no hit/kill events either
    if event_manager:
        event_manager.emit_event("after_deal_damage", {"weapon": self, "body": body, "damage_context": ctx})
        event_manager.emit_event("on_attack", {"weapon": self, "body": body, "damage_context": ctx})
        event_manager.emit_event("on_hit", {"weapon": self, "body": body, "damage_context": ctx})
        if bodyHealth.current_health <= 0:
            event_manager.emit_event("on_kill", {"weapon": self, "body": body, "damage_context": ctx})
