# A one-shot blast that fires when its owner dies. It is the damage source
# behind an enemy that detonates on death: the enemy scene carries one of these
# as an optional child, and everything standing in the blast when the enemy dies
# takes the hit.
#
# The blast is a group scan rather than a physics overlap, because the enemy
# that died has just left the "damageable" group - so the corpse is not a
# target, and everything else standing in the radius is.
extends Area2D
class_name AreaBurstOnEnter

## Damage one target takes from the blast.
@export var blast_damage: float = 10.0

## Blast radius in **meters**, the unit a designer authors. Converted to pixels
## at the only place that needs them.
@export var blast_radius: float = 0.9

var _shape: CollisionShape2D = null
var _fired: bool = false


func _ready() -> void:
    _shape = get_node_or_null("CollisionShape2D")
    if _shape != null and _shape.shape is CircleShape2D:
        # The shape is a shared sub-resource of the scene, so it is duplicated
        # before its radius is changed - otherwise every instance would fight
        # over the same one.
        var circle := (_shape.shape as CircleShape2D).duplicate() as CircleShape2D
        circle.radius = get_radius_px()
        _shape.shape = circle
    var bus := _owner_bus()
    if bus == null:
        push_warning("AreaBurstOnEnter: the owner has no EventManager, so the burst never fires.")
        return
    bus.subscribe("on_death", Callable(self, "_on_owner_died"))


## [member blast_radius] in pixels.
func get_radius_px() -> float:
    return Stats.meters_to_px(blast_radius)


## The event bus of the entity this burst belongs to.
func _owner_bus() -> EventManager:
    var owner_node := get_parent()
    if owner_node == null:
        return null
    return owner_node.get_node_or_null("EventManager") as EventManager


func _on_owner_died(_event: Dictionary) -> void:
    if _fired:
        return
    _fired = true
    var owner_node := get_parent()
    var bus := _owner_bus()
    var radius := get_radius_px()
    for target in get_tree().get_nodes_in_group("damageable"):
        if target == owner_node or not (target is Node2D):
            continue
        if global_position.distance_to((target as Node2D).global_position) > radius:
            continue
        var health := target.get_node_or_null("Health") as Health
        if health == null:
            continue
        _damage(health, target, bus)
    # The burst is over: detach, so it cannot fire a second time and does not
    # outlive the corpse it belongs to.
    queue_free()


func _damage(health: Health, target: Node, bus: EventManager) -> void:
    var ctx := DamageContext.new()
    ctx.source = get_parent()
    ctx.target = target
    ctx.base_amount = blast_damage
    ctx.final_amount = blast_damage
    ctx.tags.append("explosion")
    if bus != null:
        bus.emit_event("before_deal_damage", {"damage_context": ctx})
    if not health.apply_damage(ctx):
        return  # already dead: the blast does not land, so no hit/kill events either
    if bus != null:
        bus.emit_event("after_deal_damage", {"area_burst": self, "body": target, "damage_context": ctx})
        bus.emit_event("on_hit", {"area_burst": self, "body": target, "damage_context": ctx})
        if health.current_health <= 0:
            bus.emit_event("on_kill", {"area_burst": self, "body": target, "damage_context": ctx})
