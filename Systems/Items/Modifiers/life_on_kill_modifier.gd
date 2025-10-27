extends Node
class_name LifeOnKillModifier

var event_manager: EventManager = null
var holder: Node = null
var stats: Stats = null
var on_cooldown: bool = false
var stacks: Array[bool] = []  # each entry = active/inactive

var change_stat_name: String = "health"

const default_add_amount := 1

func attachEventManager(em: Node):
    event_manager = em
    holder = em.get_parent()
    stats = holder.get_node_or_null("Stats")
    event_manager.subscribe("on_hit", Callable(self, "_on_event"))

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
    if not stats:
        return
    var add_amount = default_add_amount * stacks.count(true)
    stats.set_base_stat(change_stat_name, stats.stats.get(change_stat_name) + add_amount)
