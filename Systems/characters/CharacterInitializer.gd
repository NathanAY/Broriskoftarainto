extends Node

# Responsible for applying selected CharacterData to the local Stats node.
func _ready():
    # Wait until owner (Character) is ready and has a Stats child
    var stats_node = null
    if owner and owner.has_node("Stats"):
        stats_node = owner.get_node("Stats")
    if not stats_node:
        return

    var char_path = null
    if typeof(GlobalGameState) != TYPE_NIL and GlobalGameState.starting_character != null:
        char_path = GlobalGameState.starting_character
    if not char_path:
        return

    var char_res = null
    if typeof(char_path) == TYPE_STRING:
        char_res = load(char_path)
    elif typeof(char_path) == TYPE_OBJECT:
        char_res = char_path

    if not char_res:
        return

    # Apply base stats (overwrite base values)
    for stat_name in char_res.base_stats.keys():
        var v = char_res.base_stats[stat_name]
        if stats_node.has_method("set_base_stat"):
            stats_node.set_base_stat(stat_name, float(v))

    # Apply modifiers (additive modifier dictionaries)
    for mod in char_res.modifiers:
        if stats_node.has_method("add_modifier"):
            stats_node.add_modifier(mod)
