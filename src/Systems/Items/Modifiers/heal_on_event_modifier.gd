extends Node
class_name HealOnEventModifier

var event_manager: EventManager = null
var holder: Node = null
var stats: Stats = null
# Format:
# { "event_name": { "variable_name": value, ... } }
var possible_trigger_event := {
    "on_attack": {"default_heal": 1},
    "on_hit": {"default_heal": 2},
    "on_crit": {"default_heal": 8},
    "after_take_damage": {"default_heal": 5},
    "before_take_damage": {"default_heal": 3}
}
@export var display_name: String = "Heal On Event"
# Exports (not plain vars) so factory-configured values survive
# PackedScene.pack() when the dynamic trigger is randomized.
@export var trigger_event: String = "on_crit"
var stacks: Array[bool] = []  # each entry = active/inactive
@export var default_heal := 1

## Dynamic tooltip fragment: the heal amount is configured per trigger
## at generation time (see possible_trigger_event), so it must be read
## off the live instance, never baked into static text.
func get_tooltip_stats() -> String:
    return "Heals %s HP" % str(default_heal)

## Generation-time hook (called by ItemFactory): pick a random trigger from
## possible_trigger_event and apply its overrides to this instance.
## Context: {"rng": RandomNumberGenerator, "stats": Dictionary}.
## Returns true when this instance was mutated (factory repacks it).
func randomize_for_generation(context: Dictionary) -> bool:
    if possible_trigger_event.is_empty():
        return false
    var rng: RandomNumberGenerator = context.get("rng")
    var event_names: Array = possible_trigger_event.keys()
    var chosen_event: String = event_names[rng.randi_range(0, event_names.size() - 1)] if rng != null else str(event_names.pick_random())
    trigger_event = chosen_event
    var overrides: Dictionary = possible_trigger_event[chosen_event]
    for key in overrides.keys():
        set(key, overrides[key])
    print("HealOnEventModifier randomized: trigger=", chosen_event, " overrides=", overrides)
    return true

func attachEventManager(em: Node):
    event_manager = em
    holder = em.get_parent()
    stats = holder.get_node_or_null("Stats")
    event_manager.subscribe(trigger_event, Callable(self, "_on_event"))

func add_stack(active: bool):
    stacks.append(active)
    prints("add_stack", stacks)

func remove_stack(index: int):
    if index >= 0 and index < stacks.size():
        stacks.remove_at(index)
    prints("remove_stack", stacks)

func set_stack_active(index: int, active: bool):
    if index >= 0 and index < stacks.size():
        stacks[index] = active
    prints("set_stack_active", stacks)

func _on_event(_event: Dictionary):
    var health: Health = holder.get_node_or_null("Health")
    if not health:
        return
    health.heal(default_heal * stacks.count(true))
