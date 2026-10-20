## A minimal stand-in for the player: a body an enemy's hitbox can detect, with
## the `Health` node every damage source looks for.
##
## The real `Character` scene carries a lot the damage pipeline does not need -
## a sprite rig, an item holder, the global game state - and a suite that only
## wants "something that can be hurt" should not have to pay for it.
class_name DamageableBody
extends RefCounted


## Spawns a damageable body at `position` under `parent` and returns its Health.
##
## The body is in the "damageable" group, so every target selector and every
## blast finds it. `in_damageable_group = false` spawns the same body outside
## the group, which is how a suite checks that a damage source filters on it.
static func spawn(parent: Node, position: Vector2, health: float = 100.0, in_damageable_group: bool = true) -> Health:
    var body := CharacterBody2D.new()
    body.name = "DamageableBody"
    # Layer 1 is the player's body layer, which is what an enemy hitbox is
    # masked to detect.
    body.collision_layer = 1
    body.collision_mask = 0
    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 30.0
    shape.shape = circle
    body.add_child(shape)
    var bus := EventManager.new()
    # A node made from a script is named after its *native* class, so these
    # names have to be set: `Health` looks its sibling up as "Stats".
    bus.name = "EventManager"
    body.add_child(bus)
    var body_stats := Stats.new()
    body_stats.name = "Stats"
    body_stats.event_manager = bus
    body_stats.set_base_stat("health", health)
    body.add_child(body_stats)
    var health_node := Health.new()
    health_node.name = "Health"
    health_node.event_manager = bus
    body.add_child(health_node)
    parent.add_child(body)
    body.global_position = position
    if in_damageable_group:
        body.add_to_group("damageable")
    return health_node
