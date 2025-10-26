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
var trigger_event: String = "on_crit"
var stacks: Array[bool] = []  # each entry = active/inactive
var default_heal := 1

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

func _on_event(event: Dictionary):
    var health: Health = holder.get_node_or_null("Health")
    if not health:
        return
    health.heal(default_heal * stacks.count(true))
