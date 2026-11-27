# res://src/scripts/weapons/AreaWeapon.gd
#
# A weapon that damages *everything* in range rather than one picked target.
#
# The range is entirely the target selector's: `BaseWeapon._on_timeout` measures
# with `weapon_range` and hands `try_shoot` every `damageable` node inside it,
# and the aura damages exactly that list. There is no second, hidden radius - on
# an `AreaWeapon`, `weapon_range` *is* the aura's reach, so the number the card
# prints ("Range: 0.66 m") is the circle the burst draws. An earlier version
# halved `weapon_range` into a private `radius`, which meant the shown range was
# twice the range that actually dealt damage.
#
# With `AllTargetsInRangeSelector` that is every `damageable` node within
# `weapon_range` of this weapon's own `sprite_node`. Combined with the sprite
# orbiting the holder at `weapon_orbit_radius`, that reads as an aura centred on
# the wielder - there is no impact point and no chosen target.
#
# Because the sprite is the origin of that measurement, the burst visual is
# placed there too, so what the player sees is exactly what was damaged.
extends BaseWeapon
class_name AreaWeapon

const BURST_SCENE := preload("res://src/Scenes/particles/area_damage_burst.tscn")

## The targets are what `_on_timeout` already found with `weapon_range`, which is
## the aura's reach, so they are damaged as handed over rather than re-queried.
func try_shoot(targets: Array[Node]) -> void:
    var holder = get_holder()
    if not holder: return
    _spawn_burst(holder, visual_radius_px(targets))
    if not attack_sound.is_empty():
        SoundManager.play(attack_sound.pick_random(), 0, 0)
    for t in targets:
        if t.has_node("Health"):
            do_damage(t)

## The pulse visual for this tick.
##
## Parented to the holder rather than to the weapon, because a weapon is a
## `Resource` and has no place in the tree; the holder is also what
## `remove_from` frees, so nothing is left behind when the weapon is unequipped.
## `local_coords` is off on both emitters, so the shards stay where they were
## thrown instead of being dragged along by a moving holder.
func _spawn_burst(holder: Node, ring_radius: float) -> void:
    var burst: AreaDamageBurst = BURST_SCENE.instantiate()
    burst.radius = ring_radius
    holder.add_child(burst)
    # After parenting, not before: an unparented Node2D has no parent transform
    # to compose, so writing `global_position` first would store the sprite's
    # world position as a *local* one and land the burst one holder-offset away.
    # `_ready` reads `radius`, so that has to be set before `add_child`.
    if sprite_node and is_instance_valid(sprite_node):
        burst.global_position = sprite_node.global_position

## The ring's radius in pixels. Hits are measured to the target's hitbox *edge*
## (`TargetSelector.reach_distance`), so a body is hit while its centre is up to
## its own radius past `get_range_px()`. The ring is drawn that much wider, using
## the largest hitbox among `targets`, so it covers what was actually hit and
## needs no fixed margin. With no targets it is the plain range.
func visual_radius_px(targets: Array[Node] = []) -> float:
    var slack := 0.0
    for t in targets:
        if t is Node2D:
            slack = maxf(slack, TargetSelector.hitbox_radius(t))
    return get_range_px() + slack

func do_damage(body):
    var ctx = DamageContext.new()
    ctx.source = get_holder()
    ctx.target = body
    ctx.base_amount = current_damage
    ctx.final_amount = current_damage
    ctx.weapon = self
    ctx.tags.append("melee")
    play_hit_sound()
    # An aura has no shot of its own, so each landed hit doubles as its attack.
    if Damage.deal(ctx, event_manager) and event_manager:
        event_manager.emit_event("on_attack", {"weapon": self, "body": body, "damage_context": ctx})
