extends Node
class_name EmergencyHealModifier

var event_manager: EventManager = null
var holder: Node = null
var stats: Stats = null
var on_cooldown: bool = false
var stacks: Array[bool] = []  # each entry = active/inactive

@export var display_name: String = "Emergency Heal"
@export var trigger_event: String = "after_take_damage"

const HEALTH_THRESHOLD := 0.25     # 25% HP
const COOLDOWN_TIME := 60.0        # seconds

func get_tooltip_stats() -> String:
    return "Heals 75%% max HP below %d%% HP, %ss cooldown" % [int(round(HEALTH_THRESHOLD * 100.0)), str(COOLDOWN_TIME)]

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
        push_warning("EmergencyHealModifier: missing EventManager!")
        return

    event_manager.subscribe(trigger_event, Callable(self, "_on_after_take_damage"))

func _on_after_take_damage(event: Dictionary):
    if on_cooldown:
        return

    var ctx: DamageContext = event.get("damage_context")
    if not ctx:
        return

    var health: Health = holder.get_node_or_null("Health")
    if not health:
        return

    var ratio := float(health.current_health) / float(health.max_health)
    if ratio <= HEALTH_THRESHOLD:
        _trigger_emergency_heal(health)

func _trigger_emergency_heal(health: Health):
    if holder and holder.has_node("Health"):
        var h: Health = holder.get_node("Health")
        h.heal(health.max_health * 0.75)
    _start_cooldown()

func _start_cooldown():
    on_cooldown = true

    var t = Timer.new()
    t.wait_time = COOLDOWN_TIME / _active_stacks() # fewer seconds per stack = faster
    t.one_shot = true
    t.connect("timeout", Callable(self, "_on_cooldown_end"))
    add_child(t)
    t.start()

func _on_cooldown_end():
    on_cooldown = false