extends Node
class_name PlusDamageToHealthyTargetModifier

var event_manager: EventManager = null
var holder: Node = null
var stats: Stats = null
var stacks: Array[bool] = []  # each entry = active/inactive

@export var display_name: String = "High Health Bonus"
@export var trigger_event: String = "before_deal_damage"

const BONUS_MULTIPLIER := 0.3        # +30 % damage
const HEALTH_THRESHOLD := 0.9        # target must be > 90 %

func get_tooltip_stats() -> String:
    return "Deals %d%% extra damage to targets above %d%% HP" % [int(round(BONUS_MULTIPLIER * 100.0)), int(round(HEALTH_THRESHOLD * 100.0))]

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
    stats = holder.get_node_or_null("Stats")

    if not event_manager:
        push_warning("PlusDamageToHealthyTargetModifier: missing EventManager!")
        return

    event_manager.subscribe(trigger_event, Callable(self, "_on_before_deal_damage"))
    event_manager.subscribe("on_stat_changes", Callable(self, "_on_stat_changes"))

func _on_before_deal_damage(event: Dictionary):
    var ctx: DamageContext = event.get("damage_context")
    if not ctx or not ctx.target:
        return

    # Get target health info
    var target_health: Health = ctx.target.get_node_or_null("Health")
    if not target_health:
        return

    var current := target_health.current_health
    var max_hp := target_health.max_health

    if max_hp <= 0:
        return

    var ratio := float(current) / float(max_hp)
    if ratio > HEALTH_THRESHOLD:
        var active_count: int = _active_stacks()  # only active stacks
        ctx.final_amount *= 1 + (BONUS_MULTIPLIER * active_count)
        ctx.tags.append("high_health_bonus")  # for debugging/logging

func _on_stat_changes(_data):
    # just access stats to refresh cache if needed
    if stats:
        stats.get_stat("damage")