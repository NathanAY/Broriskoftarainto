# res://scripts/weapons/target_selectors/HighestHealthTargetSelector.gd
extends TargetSelector
class_name HighestHealthTargetSelector

func find_targets(weapon: Node, range: float, holder: Node) -> Array[Node]:
    var best_target: Node = null
    var highest := 0

    for node in holder.get_tree().get_nodes_in_group("damageable"):
        if node == holder:
            continue
        var dist = weapon.global_position.distance_to(node.global_position)
        if dist > range:
            continue

        var health_node = node.get_node_or_null("Health")
        if health_node and health_node.current_health > highest:
            highest = health_node.current_health
            best_target = node

    if best_target:
        return [best_target]  # wrap in array
    return []  # always return an array
