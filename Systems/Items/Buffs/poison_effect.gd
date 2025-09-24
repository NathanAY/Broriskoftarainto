extends Node
class_name PoisonEffect

# Poison effect lives on the target's Health node and handles stacking + ticking.

var stacks: int = 0
var damage_per_tick: float = 0.0
var tick_interval: float = 1.0
var duration: float = 0.0
var max_stacks: int = 1
var source: Node = null
var target_health: Node = null

var _tick_timer: Timer = null
var _lifetime_timer: Timer = null

func start_effect(target: Node, damage: float, dur: float, interval: float, max_s: int, src: Node) -> void:
    # target is the Health node (the node that has take_damage())
    target_health = target
    damage_per_tick = damage
    duration = dur
    tick_interval = interval
    max_stacks = max_s
    source = src
    add_poison()

func add_poison() -> void:
    stacks = min(stacks + 1, max_stacks)
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

    var sorce_em: EventManager = null
    if source:
        sorce_em = source.get_node_or_null("EventManager")
        if sorce_em:
            sorce_em.emit_event("before_deal_damage", [{"damage_context": ctx}])
    # Run through defender phase (so armor/resists can apply)
    var target_em: EventManager = target_health.event_manager

    if target_em:
        target_em.emit_event("before_take_damage", [{"damage_context": ctx}])
    # Apply damage
    target_health.take_damage(ctx)
    if target_em:
        target_em.emit_event("after_take_damage", [{"damage_context": ctx}])

    if source and source.get_node_or_null("EventManager"):
        sorce_em.emit_event("after_deal_damage", [{"damage_context": ctx}])   

func _on_expire() -> void:
    queue_free()
