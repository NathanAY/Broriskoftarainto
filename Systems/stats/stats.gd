#stats.gd
extends Node
class_name Stats

@export var event_manager: Node  # assign LocalEventManager in editor or via code

# Base stats
@export var stats := {
    "health": 40.0,
    "energy_shield": 0,
    "damage": 10.0,
    "attack_speed": 1.0,
    "area_radius": 1.0,
    "attack_range": 500.0,
    "movement_speed": 50,
    "armor": 0,
    "critical_chance": 0.0,
    "critical_multiplier": 1.0,
    "projectile_pierce": 0,
}
# All conditions are numeric (0/1 or seconds)
var conditions := {
    "standing_still": 0.0,
    "standing_still_seconds": 0.0,
    "moving": 0.0,
    "shooting": 0.0,
    "poisoned": 0.0,
    "surrounded": 0.0,
}

# Active modifiers: array of dicts, possibly with "condition" key
# Example:
# {"damage": {"flat": 5}, "condition": {"is_standing_still": 1}}
var modifiers: Array = []

# Condition managers (each can track conditions like standing_still, is_moving)
var condition_managers: Array = []

# ----------------
# Stats
# ----------------
func get_stat(stat_name: String) -> float:
    var base_value = stats.get(stat_name, 0.0)
    var final_value = base_value
    for mod in modifiers:
        if mod.has(stat_name):
            # If modifier has condition → check if it’s met
            if mod.has("condition") and not _check_condition(mod["condition"]):
                continue
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
        if stat_name == "condition": 
            continue
        var final_value = get_stat(stat_name)
        if event_manager:
            event_manager.emit_event("on_stat_changes", [{"stat_name" :stat_name, "final_value": final_value}])
        else:
            print("Stats: No event manager")    

func remove_modifier(mod: Dictionary):
    modifiers.erase(mod)
    for stat_name in mod.keys():
        if stat_name == "condition": 
            continue
        var final_value = get_stat(stat_name)
        if event_manager:
            event_manager.emit_event("on_stat_changes", [{"stat_name" :stat_name, "final_value": final_value}])

# -----------------
# Conditions
# -----------------
func add_condition_manager(manager: Node) -> void:
    if manager in condition_managers:
        return
    condition_managers.append(manager)
    # Allow the manager to emit events back to stats
    if manager.has_method("set_stats_reference"):
        manager.set_stats_reference(self)

func set_condition(name: String, value: float) -> void:
    if conditions.get(name, -1) != value:
        conditions[name] = value
        if event_manager:
            event_manager.emit_event("on_stat_changes", [{"stat_name" :name, "final_value": value}])
            event_manager.emit_event("on_condition_change", [{"name" :name, "value": value}])

func get_condition(name: String) -> float:
    return conditions.get(name, 0.0)

# ----------------
# Helpers
# ----------------
func _check_condition(cond: Dictionary) -> bool:
    # Supports numeric thresholds
    for cname in cond.keys():
        var required_val = cond[cname]
        var current_val = get_condition(cname)

        if typeof(required_val) in [TYPE_FLOAT, TYPE_INT]:
            if current_val < float(required_val):
                return false
        else:
            if current_val != required_val:
                return false
    return true

var _condition_update_accum: float = 0.0
var condition_update_interval: float = 0.5  # seconds                

func _process(delta: float) -> void:
    _condition_update_accum += delta
    if _condition_update_accum <= condition_update_interval:
        return
    _condition_update_accum = 0.0
    _update_condition_managers()

func _update_condition_managers() -> void:
    for manager in condition_managers:
        if manager.has_method("update"):
            manager.update(condition_update_interval)
