extends Resource
class_name Item

@export var name: String
@export var description: String
@export var modifiers: Dictionary = {} # optional stat modifiers ex: {"damage": {"flat": 5}, "condition": "standing_still"}}
@export var effect_scene: Array [PackedScene] #optional, for special effects (explosions, spread shot, chain projectiles, crit)
@export var effect_scene_condition: Array[String] = [] # optional effect_scene condition. ex: "standing_still"
@export var condition_managers: Array[PackedScene] = [] # optional condition managers

# Apply modifiers / effects to a holder (holder = Node that has "Stats" child)
func apply_to(holder: Node) -> void:
    if not holder:
        return
    var stats_node: Stats = holder.get_node_or_null("Stats")
    if stats_node and modifiers:
        stats_node.add_modifier(modifiers)
        # Spawn condition managers
    for cm_scene in condition_managers:
        var cm = cm_scene.instantiate()
        stats_node.add_condition_manager(cm)    

# Remove modifiers
func remove_from(holder: Node) -> void:
    if not holder:
        return
    var stats_node = holder.get_node_or_null("Stats")
    if stats_node and modifiers:
        stats_node.remove_modifier(modifiers)
    #todo remove condition manager too
