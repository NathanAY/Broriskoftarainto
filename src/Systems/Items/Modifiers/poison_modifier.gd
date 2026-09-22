extends BaseModifier

# Preload the PoisonEffect script (change path if you saved it elsewhere)
const _PoisonEffect = preload("res://src/Systems/Items/Buffs/poison_effect.gd")

@export var display_name: String = "Poison"
@export var trigger_event: String = "on_hit"

@export var poison_chance: float = 0.9993
@export var duration: float = 3.0
@export var tick_interval: float = 1.0
@export var max_stacks: int = 500
@export var damage_per_stack: float = 0.5 # +50% tick damage per stack

## Poison damage per tick equals 100% of the triggering hit's base damage.
func get_tooltip_stats() -> String:
    return "Poison deals 100%% of hit damage per tick for %ss" % str(duration)

func attachEventManager(em: Node):
    _cache_holder(em)
    # subscribe to on_hit (so poison is applied only on successful hits)
    _subscribe(trigger_event, Callable(self, "_on_hit"))

func _on_hit(event: Dictionary) -> void:
    if not _is_bound_event(event):
        return
    # event expected to be a Dictionary: {"projectile":..., "body":..., "damage_context":...}
    var body = event.get("body", null)
    if not body:
        return
    if not body.has_node("Health"):
        return

    # chance roll
    if randf() > poison_chance:
        return

    var health_node = body.get_node("Health")
    # Check existing PoisonEffect on the Health node
    var existing: PoisonEffect = health_node.get_node_or_null("PoisonEffect")
    var base_damage := float(event["damage_context"].base_amount) * (1.0 + (damage_per_stack * (_active_stacks() - 1)))
    if existing:
        existing.add_poison()
    else:
        var p = PoisonEffect.new()
        p.name = "PoisonEffect"
        health_node.add_child(p)
        p.tick_interval = tick_interval
        p.duration = duration
        p.max_stacks = max_stacks
        p.source = holder
        p.start_effect(health_node, base_damage, duration, tick_interval, max_stacks, holder)