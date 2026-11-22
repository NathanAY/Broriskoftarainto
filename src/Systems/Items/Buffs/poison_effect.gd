extends Node
class_name PoisonEffect

# Poison effect lives on the target's Health node and handles stacking + ticking.

const _PARTICLES: PackedScene = preload("res://src/Scenes/particles/poison_particles.tscn")

var stacks: int = 0
var damage_per_tick: float = 0.0
var tick_interval: float = 1.0
var duration: float = 0.0
var max_stacks: int = 1
var source: Node = null
var target_health: Node = null

var _tick_timer: Timer = null
var _lifetime_timer: Timer = null
var _particles: PoisonParticles = null

func start_effect(target: Node, damage: float, dur: float, interval: float, max_s: int, src: Node) -> void:
    # target is the Health node (the node that has apply_damage())
    target_health = target
    damage_per_tick = damage
    duration = dur
    tick_interval = interval
    max_stacks = max_s
    source = src
    add_poison()

func add_poison() -> void:
    stacks = min(stacks + 1, max_stacks)
    _show_stacks()
    # ensure tick timer exists
    if not _tick_timer:
        _tick_timer = Timer.new()
        _tick_timer.one_shot = false
        _tick_timer.wait_time = tick_interval
        _tick_timer.timeout.connect(Callable(self, "_on_tick"))
        add_child(_tick_timer)
        _tick_timer.start()
    else:
        # adjust interval if changed
        _tick_timer.wait_time = tick_interval
    # reset / restart lifetime timer
    if _lifetime_timer:
        _lifetime_timer.stop()
        _lifetime_timer.queue_free()
        _lifetime_timer = null

    _lifetime_timer = Timer.new()
    _lifetime_timer.one_shot = true
    _lifetime_timer.wait_time = duration
    _lifetime_timer.timeout.connect(Callable(self, "_on_expire"))
    add_child(_lifetime_timer)
    _lifetime_timer.start()

func _on_tick() -> void:
    if not target_health or not target_health.is_inside_tree():
        queue_free()
        return

    # Build DamageContext consistent with your pipeline:
    var ctx = DamageContext.new()
    if source:
        ctx.source = source
    ctx.target = target_health.get_parent()   # entity node that owns the Health
    ctx.base_amount = damage_per_tick * stacks
    ctx.final_amount = ctx.base_amount
    ctx.tags.append("poison")
    ctx.can_crit = false  # damage over time never crits

    # Health drops the tick if the target died in the meantime, so a corpse
    # cannot be re-killed once per second for the death animation.
    var source_bus: EventManager = null
    if is_instance_valid(source):
        source_bus = source.get_node_or_null("EventManager")
    Damage.deal(ctx, source_bus)

## Puts the bubble visual on the poisoned entity (the Health node's owner) and
## keeps its density in step with `stacks`.
func _show_stacks() -> void:
    if _particles == null:
        var body := target_health.get_parent() as Node2D if target_health else null
        if body == null:
            return
        _particles = _PARTICLES.instantiate()
        body.add_child(_particles)
    _particles.set_stacks(stacks)

func _on_expire() -> void:
    if _particles != null:
        _particles.fade_out()
    _tick_timer.queue_free()
    _lifetime_timer.queue_free()
    queue_free()
    
