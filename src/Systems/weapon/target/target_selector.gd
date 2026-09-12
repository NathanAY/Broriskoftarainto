# res://src/scripts/weapons/target_selectors/TargetSelector.gd
extends Resource
class_name TargetSelector

# holder is the weapon's owner (the entity who wields the weapon)
# enemies are nodes in group "damageable"
func find_targets(_origin: Node, _range: float, _ignore_node: Node) -> Array[Node]:
    return []  # override in subclasses
