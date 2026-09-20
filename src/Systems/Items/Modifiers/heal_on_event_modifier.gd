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
