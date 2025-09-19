# res://scripts/target_selectors/closest_target_selector.gd
extends TargetSelector
class_name ClosestTargetSelector

func find_targets(origin: Node, range: float, ignore_node: Node) -> Array[Node]:
    var closest: Node = null
    var closest_dist := INF
    var results: Array[Node] = []

    for node in origin.get_tree().get_nodes_in_group("damageable"):
        if node == ignore_node:  # skip the holder itself
            continue
        if _should_skip(ignore_node, node):
            continue
        var dist = origin.global_position.distance_to(node.global_position)
        if dist <= range and dist < closest_dist:
            closest_dist = dist
            closest = node

    if closest:
        results.append(closest)
    return results

func _should_skip(holder: Node, node: Node) -> bool:
    for g in holder.get_groups().filter(func(gr): return gr != "damageable"):
        if node.is_in_group(g):
            return true
    return false
