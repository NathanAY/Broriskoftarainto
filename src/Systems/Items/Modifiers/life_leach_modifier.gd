extends Node
class_name LifeLeachModifier

var event_manager: EventManager = null
var holder: Node = null
var stats: Stats = null
var on_cooldown: bool = false
var stacks: Array[bool] = []  # each entry = active/inactive

const default_leach := 0.05     # 5% of damage

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
    var health: Health = holder.get_node_or_null("Health")
    if not health:
        return
    var dc: DamageContext = event.get("damage_context")
    var stacks_multiplier = 5.0 / (4 + stacks.count(true))# +20% per stack
    var leach_amount = default_leach * dc.final_amount
    health.heal(leach_amount * stacks_multiplier)
