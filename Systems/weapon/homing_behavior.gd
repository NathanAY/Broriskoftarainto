extends Node

@export var homing_strength: float = 2.0   # radians per second
@export var homing_range: float = 400.0    # how far it can lock on

var holder: Node
var projectile: Projectile
var target: Node = null
var target_position: Vector2

func _ready():
    projectile = get_parent()
    if not projectile or not projectile.has_method("set_direction"):
        queue_free()
        return

    # ✅ copy target from projectile if it has one
    if projectile.target:
        target = projectile.target
        target_position = target.global_position

func _physics_process(delta):
    if not projectile:
        return

    if not target or not is_instance_valid(target):
        target = _find_target()
        return

    var to_target = (target.global_position - projectile.global_position).normalized()
    var angle_diff = projectile.direction.angle_to(to_target)

    # Clamp rotation speed
    var max_rotation = homing_strength * delta
    angle_diff = clamp(angle_diff, -max_rotation, max_rotation)

    # Apply new direction
    projectile.direction = projectile.direction.rotated(angle_diff).normalized()

func _find_target() -> Node:
    var closest_target: Node = null
    var closest_dist = INF

    for node in get_tree().get_nodes_in_group("damageable"):
        if node == holder:
            continue

        # skip allies (same groups as holder except "damageable")
        var skip = false
        for g in holder.get_groups():
            if g == "damageable":
                continue
            if node.is_in_group(g):
                skip = true
                break
        if skip:
            continue

        var dist = target_position.distance_to(node.global_position)
        if dist <= homing_range and dist < closest_dist:
            closest_dist = dist
            closest_target = node           

    return closest_target
