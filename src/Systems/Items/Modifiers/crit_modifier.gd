extends Node
class_name CritModifier

var event_manager: EventManager = null
var holder: Node = null
var stats: Stats = null
var stacks: Array[bool] = []  # each entry = active/inactive

@export var display_name: String = "Crit"
@export_multiline var tooltip_text: String = "Critical hits deal extra damage based on your critical chance and multiplier."
@export var trigger_event: String = "before_deal_damage"
@export var crit_multiplier_per_stack: float = 0.15

var _current_crit = 0
var _current_crit_multiplier = 0.0

func get_tooltip_stats() -> String:
    return "+%.2f crit multiplier per stack" % crit_multiplier_per_stack

func _active_stacks() -> int:
    return max(1, stacks.count(true))

func add_stack(active: bool):
    stacks.append(active)

func remove_stack(index: int):
    if index >= 0 and index < stacks.size():
        stacks.remove_at(index)

func set_stack_active(index: int, active: bool):
    if index >= 0 and index < stacks.size():
        stacks[index] = active

func attachEventManager(em: Node):
    event_manager = em
    holder = em.get_parent()
    stats = holder.get_node("Stats")
    em.subscribe("before_deal_damage", Callable(self, "_on_before_deal_damage"))
    em.subscribe("on_stat_changes", Callable(self, "_on_stat_changes"))

func _on_before_deal_damage(event):
    if randf() * 100 < _current_crit:
        var ctx: DamageContext = event["damage_context"]
        ctx.final_amount *= _current_crit_multiplier + (crit_multiplier_per_stack * (_active_stacks() - 1))
        ctx.is_crit = true
        event_manager.emit_event("on_crit", {"damage_context": ctx})

func _on_stat_changes(_event):
    _current_crit = stats.get_stat("critical_chance")
    _current_crit_multiplier = stats.get_stat("critical_multiplier")