extends Node
class_name MoreDamageToHealtyModifier

var event_manager: EventManager = null
var holder: Node = null
var stats: Stats = null
var stacks: Array[bool] = []  # each entry = active/inactive

const BONUS_MULTIPLIER := 0.3        # +30 % damage
const HEALTH_THRESHOLD := 0.9        # target must be > 90 %

func attachEventManager(em: Node):
    event_manager = em
    holder = em.get_parent()
    stats = holder.get_node_or_null("Stats")

    if not event_manager:
        push_warning("HighHealthBonusDamage: missing EventManager!")
        return

    event_manager.subscribe("before_deal_damage", Callable(self, "_on_before_deal_damage"))
    event_manager.subscribe("on_stat_changes", Callable(self, "_on_stat_changes"))

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
        var active_count: int = stacks.count(true)  # ✅ only active stacks
        ctx.final_amount *= 1 + (BONUS_MULTIPLIER * active_count)
        ctx.tags.append("high_health_bonus")  # for debugging/logging

func _on_stat_changes(_data):
    # just access stats to refresh cache if needed
    if stats:
        stats.get_stat("damage")
