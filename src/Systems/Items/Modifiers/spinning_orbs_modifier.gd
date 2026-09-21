extends Node
class_name SpinningOrbsModifier

@export var orb_scene: PackedScene = preload("res://src/Scenes/OrbitingOrb.tscn")

const ORB_COUNT := 2
const DURATION := 3.0
const ORBIT_RADIUS := 90
const ORBIT_SPEED := 180  # degrees per second
const DAMAGE := 0.5 # 50% of base damage

var event_manager: EventManager = null
var holder: Node = null
var stats: Stats = null
var ignore_groups: Array[StringName] = []
var stacks: Array[bool] = []
@export var display_name: String = "Spinning Orbs"
var modifier_meta := "spawned_by_SpinningOrbsModifier"
# Export so the value survives PackedScene.pack() if ever dynamically configured.
@export var trigger_event := "on_hit"# "on_hit" "on_kill"
var _current_base_damage: float
var _current_damage_multiplier: float

func _active_stacks() -> int:
    return max(1, stacks.count(true))

func attachEventManager(em: Node):
    event_manager = em
    holder = em.get_parent()
    stats = holder.get_node_or_null("Stats")
    ignore_groups = holder.get_groups().filter(func(g): return g != "damageable")
    event_manager.subscribe(trigger_event, Callable(self, "_on_triger"))
    event_manager.subscribe("on_stat_changes", Callable(self, "_on_stat_changes"))

func add_stack(active: bool):
    stacks.append(active)

func remove_stack(index: int):
    if index >= 0 and index < stacks.size():
        stacks.remove_at(index)

func set_stack_active(index: int, active: bool):
    if index >= 0 and index < stacks.size():
        stacks[index] = active

func get_tooltip_stats() -> String:
    return "Orbs deal %d%% of base damage" % int(round(DAMAGE * 100.0))

func _on_triger(event: Dictionary):
    if trigger_event == "on_hit":
        var dc: DamageContext = event.get("damage_context")
        if dc.tags.has(modifier_meta):
            return
    call_deferred("_spawn_orbs")

func _spawn_orbs():
    # spawn new orbs (+1 orb per additional stack)
    var damage = _current_base_damage * DAMAGE * _current_damage_multiplier
    var orb_count = ORB_COUNT + (_active_stacks() - 1)
    var active_orbs: Array[Node] = []
    for i in range(orb_count):
        var orb: SpinningOrb = orb_scene.instantiate()
        orb.orbit_center = holder
        orb.orbit_radius = ORBIT_RADIUS
        orb.damage = damage
        orb.orbit_speed = ORBIT_SPEED
        orb.angle_offset = i * (360.0 / orb_count)
        orb.ignore_groups = ignore_groups
        orb.event_manager = event_manager
        orb.set_meta(modifier_meta, true)
        holder.add_child(orb)
        active_orbs.append(orb)

    # schedule removal
    var timer := Timer.new()
    timer.one_shot = true
    timer.wait_time = DURATION
    timer.connect("timeout", Callable(self, "_remove_orbs").bind(timer, orb_count, active_orbs))
    add_child(timer)
    timer.start()

func _remove_orbs(timer: Timer, how_many: int, active_orbs: Array[Node]):
    for i in range(how_many):
        active_orbs.pop_front().queue_free()
    timer.queue_free()

func _on_stat_changes(_event):
    _current_base_damage = stats.get_stat("base_damage")
    _current_damage_multiplier = stats.get_stat("damage")