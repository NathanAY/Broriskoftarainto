extends Node
class_name HealtOnEventModifier

var event_manager: EventManager = null
var holder: Node = null
var stats: Stats = null
var on_cooldown: bool = false
var trigger_event: String = "on_hit" #"on_attack", "on_hit", "after_take_damage", "before_take_damage"
var stacks: Array[bool] = []  # each entry = active/inactive

const default_heal := 1     # 25% HP

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
