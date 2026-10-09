#stats.gd
extends Node
class_name Stats

@export var event_manager: Node  # assign LocalEventManager in editor or via code

## World unit scale: 300 pixels = 1 meter. Anything a designer tunes or the
## player is shown - a stat, a weapon's range, a knockback strength - is stored
## in meters; `meters_to_px()` is the only place that becomes pixels, at the
## boundary where the value is handed to the physics server or a `Vector2`.
const PIXELS_PER_METER: float = 300.0

## The one conversion, for every meter-valued quantity in the project. Prefer
## this over multiplying by [constant PIXELS_PER_METER] inline: it keeps the
## unit of a caller obvious (`to_px(meters)` reads as meters at the call site)
## and means the scale lives in exactly one place.
static func meters_to_px(meters: float) -> float:
    return meters * PIXELS_PER_METER

## The inverse, for authoring and for tests that check a `.tres` against the
## pixel value the game actually plays at.
static func px_to_meters(pixels: float) -> float:
    return pixels / PIXELS_PER_METER

## Canonical base values, shared by every character. `CharacterData.base_stats`
## overrides a subset of these, so UI that needs to know whether a character's
## value is above or below the norm (the character select screen) compares
## against this table rather than hardcoding its own numbers.
const DEFAULT_STATS := {
    "health": 10.0,
    "energy_shield": 0.0,
    "damage": 1.0,
    "base_damage": 5.0,
    "flat_damage": 0.0,
    "attack_speed": 1.0,
    "area_radius": 1.0,
    "attack_range": 1.67,
    "movement_speed": 1.0,
    "critical_chance": 0.0,
    "critical_multiplier": 1.5,
    "area_size_multiplier": 1.0,
    "projectile_pierce": 0.0,
    "projectile_speed_multiplier": 1.0,
}

# Base stats
@export var stats := DEFAULT_STATS.duplicate()


## The value a stat starts at before any modifier. Missing stats have no
## default, so they report 0.0 and read as neutral.
static func default_stat(stat_name: String) -> float:
    return float(DEFAULT_STATS.get(stat_name, 0.0))
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

# Provided-stat reference counts: stat_name -> number of live modifier instances.
# Presence of a dynamic stat is tied to these counts; claim on first attach,
# release on last detach erases the key.
var _provided_counts: Dictionary = {}

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

## movement_speed is stored in meters per second; convert to pixels per second
## for physics (300 px = 1 m).
func get_movement_speed_px() -> float:
    return meters_to_px(get_stat("movement_speed"))


func set_base_stat(stat_name: String, value: float):
    stats[stat_name] = value
    var final_value = get_stat(stat_name)
    event_manager.emit_event("on_stat_changes", {"stat_name" :stat_name, "final_value": final_value})
    return final_value

func add_modifier(mod: Dictionary):
    # Example: {"damage": {"flat": 5, "percent": 0.2}}
    modifiers.append(mod)
    for stat_name in mod.keys():
        if stat_name == "condition": 
            continue
        var final_value = get_stat(stat_name)
        if event_manager:
            event_manager.emit_event("on_stat_changes", {"stat_name" :stat_name, "final_value": final_value})
        else:
            print("Stats: No event manager")    

func remove_modifier(mod: Dictionary):
    modifiers.erase(mod)
    for stat_name in mod.keys():
        if stat_name == "condition": 
            continue
        var final_value = get_stat(stat_name)
        if event_manager:
            event_manager.emit_event("on_stat_changes", {"stat_name" :stat_name, "final_value": final_value})

# ----------------
# Provided (dynamic) stats
# ----------------
## A behavior modifier advertising `provided_stat` claims the stat through here.
## First claim installs `default_value` as the stat base; later claims (more
## modifier instances sharing the stat) just bump the reference count.
func claim_provided_stat(stat_name: String, default_value: float) -> void:
    if _provided_counts.get(stat_name, 0) == 0:
        stats[stat_name] = default_value
        if event_manager:
            event_manager.emit_event("on_stat_changes", {"stat_name": stat_name, "final_value": default_value})
    _provided_counts[stat_name] = _provided_counts.get(stat_name, 0) + 1

## Release one modifier instance's claim. At count zero the stat key is erased,
## so a dynamic stat only exists while at least one owning modifier is attached.
func release_provided_stat(stat_name: String) -> void:
    if not _provided_counts.has(stat_name):
        return
    _provided_counts[stat_name] -= 1
    if _provided_counts[stat_name] <= 0:
        _provided_counts.erase(stat_name)
        stats.erase(stat_name)
        if event_manager:
            event_manager.emit_event("on_stat_changes", {"stat_name": stat_name, "final_value": 0.0})

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

func set_condition(conditionName: String, value: float) -> void:
    if conditions.get(conditionName, -1) != value:
        conditions[conditionName] = value
        if event_manager:
            event_manager.emit_event("on_stat_changes", {"stat_name" :conditionName, "final_value": value})
            event_manager.emit_event("on_condition_change", {"condition_name" :conditionName, "value": value})

func get_condition(conditionName: String) -> float:
    return conditions.get(conditionName, 0.0)

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

static func get_stat_icon(stat_name: String) -> Texture2D:
    var path = "res://src/Assets/stats/%s.png" % stat_name
    if ResourceLoader.exists(path):
        return load(path)
    return load("res://src/Assets/stats/_default.png")
