# res://src/scripts/weapons/target_selectors/TargetSelector.gd
extends Resource
class_name TargetSelector

# holder is the weapon's owner (the entity who wields the weapon)
# enemies are nodes in group "damageable"
func find_targets(_origin: Node, _range: float, _ignore_node: Node) -> Array[Node]:
    return []  # override in subclasses


## Distance in pixels from `from` to the edge of `target`'s hitbox, or to its
## centre when it has no circular hitbox. Range checks use this instead of the
## centre distance, so a big creature is in reach as soon as its body is, and
## its size is part of the answer rather than something its centre hides.
static func reach_distance(from: Vector2, target: Node2D) -> float:
    var dist := from.distance_to(target.global_position)
    var shape_node := target.get_node_or_null("Hitbox/CollisionShape2D") as CollisionShape2D
    if shape_node == null:
        shape_node = target.get_node_or_null("CollisionShape2D") as CollisionShape2D
    if shape_node != null and shape_node.shape is CircleShape2D:
        dist -= (shape_node.shape as CircleShape2D).radius * shape_node.global_scale.x
    return maxf(dist, 0.0)
