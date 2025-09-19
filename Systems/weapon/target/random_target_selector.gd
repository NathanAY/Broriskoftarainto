# res://scripts/weapons/target_selectors/RandomTargetSelector.gd
extends TargetSelector
class_name RandomTargetSelector

func find_targets(weapon: Node, range: float, holder: Node) -> Array[Node]:
    var candidates: Array = []
    for node in holder.get_tree().get_nodes_in_group("damageable"):
        if node == holder:
            continue
        if weapon.global_position.distance_to(node.global_position) <= range:
            candidates.append(node)
    if candidates.is_empty():
        return []
    return [candidates.pick_random()]
