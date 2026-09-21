extends Node
class_name LifeLeachModifier

@export var display_name: String = "Life Leach"
@export var trigger_event: String = "on_hit"
@export var bonus_per_stack: float = 0.2 # +20% leech power per stack

var event_manager: EventManager = null
var holder: Node = null
var stats: Stats = null
var on_cooldown: bool = false
var stacks: Array[bool] = []  # each entry = active/inactive

const default_leach := 0.05     # 5% of damage

func get_tooltip_stats() -> String:
    return "Heals %d%% of dealt damage" % int(round(default_leach * 100.0))

func _active_stacks() -> int:
    return max(1, stacks.count(true))

func attachEventManager(em: Node):
    event_manager = em
    holder = em.get_parent()
    stats = holder.get_node_or_null("Stats")
    event_manager.subscribe(trigger_event, Callable(self, "_on_event"))

func add_stack(active: bool):
    stacks.append(active)

func remove_stack(index: int):
    if index >= 0 and index < stacks.size():
        stacks.remove_at(index)

func set_stack_active(index: int, active: bool):
    if index >= 0 and index < stacks.size():
        stacks[index] = active

func _on_event(event: Dictionary):
    var health: Health = holder.get_node_or_null("Health")
    if not health:
        return
    var dc: DamageContext = event.get("damage_context")
    var stacks_multiplier = 1.0 + (bonus_per_stack * (_active_stacks() - 1)) # +20% per stack
    var leach_amount = default_leach * dc.final_amount
    health.heal(leach_amount * stacks_multiplier)