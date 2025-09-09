extends Resource
class_name Item

@export var name: String
@export var description: String
@export var modifiers: Dictionary = {} # ex: {"damage": {"flat": 5}}
@export var effect_scene: PackedScene # optional, for special effects (explosions, burns)

# Apply modifiers / effects to a holder (holder = Node that has "Stats" child)
func apply_to(holder: Node) -> void:
    if not holder:
        return
    var stats_node = holder.get_node_or_null("Stats")
    if stats_node and modifiers:
        stats_node.add_modifier(modifiers)

# Remove modifiers
func remove_from(holder: Node) -> void:
    if not holder:
        return
    var stats_node = holder.get_node_or_null("Stats")
    if stats_node and modifiers:
        stats_node.remove_modifier(modifiers)
