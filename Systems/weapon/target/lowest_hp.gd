# res://scripts/weapons/target_selectors/LowestHealthTargetSelector.gd
extends TargetSelector
class_name LowestHealthTargetSelector

func find_targets(holder: Node, range: float) -> Array[Node]:
    var best_target: Node = null
    var best := INF

    for node in holder.get_tree().get_nodes_in_group("damageable"):
        if node == holder:
            continue
        var dist = holder.global_position.distance_to(node.global_position)
        if dist > range:
            continue

        var health_node = node.get_node_or_null("Health")
        if health_node and health_node.current_health < best:
            best = health_node.current_health
            best_target = node

    if best_target:
        return [best_target]  # wrap in array
    return []  # always return an array
