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

## Seconds between the owner dying and the blast going off. 0 detonates on death.
@export var detonation_delay: float = 0.0

## The blast visual, sized to the same radius the damage scan uses.
@export var burst_scene: PackedScene = preload("res://src/Scenes/particles/explosion_burst.tscn")

var _shape: CollisionShape2D = null
var _fired: bool = false
var _corpse: Node = null
var _bus: EventManager = null


## Plays the blast at this node's position, parented beside it so it outlives it.
func _spawn_visual(radius: float) -> void:
    if burst_scene == null or get_parent() == null:
        return
    var burst := burst_scene.instantiate() as ExplosionBurst
    if burst == null:
        return
    burst.radius = radius
    get_parent().add_child(burst)
    burst.global_position = global_position


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
    _corpse = get_parent()
    _bus = _owner_bus()
    if detonation_delay <= 0.0:
        _detonate()
        return
    # The corpse is freed when its death animation ends, which is sooner than the
    # delay, so the burst moves to the corpse's parent and waits there. Deferred:
    # the death event fires inside Health.apply_damage, a physics callback.
    var home := _corpse.get_parent()
    if home == null:
        _detonate()
        return
    reparent.call_deferred(home, true)
    _light_fuse()
    get_tree().create_timer(detonation_delay).timeout.connect(_detonate)


## The telegraph rides along as a child, so it is freed with the burst. It takes
## over drawing the creature, so the corpse's own visual is hidden: otherwise its
## death spin would play on top of the swelling body.
func _light_fuse() -> void:
    var fuse := DetonationFuse.new()
    fuse.duration = detonation_delay
    var sprite := _corpse.get_node_or_null("Node2D/Sprite2D") as Sprite2D
    if sprite != null and sprite.texture != null:
        fuse.copy_sprite(sprite, global_position)
        var holder := sprite.get_parent() as CanvasItem
        if holder != null:
            holder.visible = false
    add_child.call_deferred(fuse)


func _detonate() -> void:
    if not is_inside_tree():
        return
    var owner_node := _corpse if is_instance_valid(_corpse) else null
    var bus := _bus if is_instance_valid(_bus) else null
    var radius := get_radius_px()
    _spawn_visual(radius)
    for target in get_tree().get_nodes_in_group("damageable"):
        if target == owner_node or not (target is Node2D):
            continue
        if global_position.distance_to((target as Node2D).global_position) > radius:
            continue
        _damage(target, bus)
    # The burst is over: detach, so it cannot fire a second time and does not
    # outlive the corpse it belongs to.
    queue_free()


func _damage(target: Node, bus: EventManager) -> void:
    var ctx := DamageContext.new()
    ctx.source = _corpse if is_instance_valid(_corpse) else null
    ctx.target = target
    ctx.base_amount = blast_damage
    ctx.final_amount = blast_damage
    ctx.tags.append("explosion")
    Damage.deal(ctx, bus)
