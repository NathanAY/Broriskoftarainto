extends Node
class_name PoisonModifier

# Preload the PoisonEffect script (change path if you saved it elsewhere)
const PoisonEffect = preload("res://Systems/Items/Buffs/poison_effect.gd")

var event_manager: Node = null
var holder: Node = null
var stats: Node = null

@export var poison_chance: float = 0.9993
@export var poison_damage: float = 2.0
@export var duration: float = 3.0
@export var tick_interval: float = 1.0
@export var max_stacks: int = 500

func attachEventManager(em: Node):
    event_manager = em
    holder = em.get_parent()
    stats = holder.get_node_or_null("Stats")
    # subscribe to on_hit (so poison is applied only on successful hits)
    em.subscribe("on_hit", Callable(self, "_on_on_hit"))

func _on_on_hit(event) -> void:
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
    if existing:
        existing.add_poison()
    else:
        var p = PoisonEffect.new()
        p.name = "PoisonEffect"
        health_node.add_child(p)
        p.damage_per_tick = poison_damage
        p.tick_interval = tick_interval
        p.duration = duration
        p.max_stacks = max_stacks
        p.source = holder
        p.start_effect(health_node, poison_damage, duration, tick_interval, max_stacks, holder)
