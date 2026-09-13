# res://src/scripts/weapons/target_selectors/AllTargetsInRangeSelector.gd
extends TargetSelector
class_name AllTargetsInRangeSelector

func find_targets(weapon: Node, find_range: float, holder: Node) -> Array[Node]:
    var targets: Array[Node] = []
    for node in holder.get_tree().get_nodes_in_group("damageable"):
        if node == holder:
            continue
        var dist = weapon.global_position.distance_to(node.global_position)
        if dist <= find_range:
            targets.append(node)
    return targets
