#stats.gd
extends Node
class_name Stats

@export var event_manager: Node  # assign LocalEventManager in editor or via code

# Base stats
@export var stats := {
    "health": 40.0,
    "damage": 10.0,
    "attack_speed": 2.0,
    "area_radius": 1.0,
    "attack_range": 500.0,
}

# Active modifiers (items, buffs, debuffs, etc.)
var modifiers: Array = []

func get_stat(stat_name: String) -> float:
    var base_value = stats.get(stat_name, 0.0)
    var final_value = base_value
    for mod in modifiers:
        if mod.has(stat_name):
            final_value += mod[stat_name].get("flat", 0.0)
            final_value *= 1.0 + mod[stat_name].get("percent", 0.0)
    return final_value

func set_base_stat(stat_name: String, value: float):
    stats[stat_name] = value
    var final_value = get_stat(stat_name)
    event_manager.emit_event("on_stat_changes", [{"stat_name" :stat_name, "final_value": final_value}])
    return final_value

func add_modifier(mod: Dictionary):
    # Example: {"damage": {"flat": 5, "percent": 0.2}}
    modifiers.append(mod)
    for stat_name in mod.keys():
        var final_value = get_stat(stat_name)
        if event_manager:
            event_manager.emit_event("on_stat_changes", [{"stat_name" :stat_name, "final_value": final_value}])

func remove_modifier(mod: Dictionary):
    modifiers.erase(mod)
    for stat_name in mod.keys():
        var final_value = get_stat(stat_name)
        if event_manager:
            event_manager.emit_event("on_stat_changes", [{"stat_name" :stat_name, "final_value": final_value}])
