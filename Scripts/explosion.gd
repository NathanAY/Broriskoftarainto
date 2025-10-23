# Explosion.gd
extends Area2D

@export var radius: float = 100.0
@export var damage: int = 10
@export var duration: float = 0.15
var time_passed: float = 0.0

var event_manager: EventManager = null 
var holder: Node = null
var stats: Stats = null

func _ready():
    if stats:
        var area_multiplier: float = stats.get_stat("area_size_multiplier")
        radius *= area_multiplier
    $CollisionShape2D.shape.radius = radius
    connect("body_entered", Callable(self, "_on_body_entered"))

func attachEventManager(em: EventManager):
    event_manager = em
    holder = em.get_parent()
    stats = holder.get_node_or_null("Stats")

func _process(delta: float):
    time_passed += delta
    if time_passed >= duration:
        queue_free()

func _draw():
    var alpha = 1.0 - (time_passed / duration) # fade out
    var color = Color(1, 1, 1, 0.5 * alpha)  # orange, half opacity
    draw_circle(Vector2.ZERO, radius, color)

func _on_body_entered(body: Node):
    if body.has_node("Health"):
        do_damage(body)
    else:
        print("Explosion.gd: Body has no Health node!")
    

func do_damage(body):
    var ctx = DamageContext.new()
    ctx.source = self
    ctx.target = body
    ctx.base_amount = damage
    ctx.final_amount = damage
    ctx.tags.append("explosion")
    if event_manager: 
        event_manager.emit_event("before_deal_damage", [{"damage_context": ctx}])
    var bodyHealth: Health = body.get_node("Health")
    bodyHealth.event_manager.emit_event("before_take_damage", [{"damage_context": ctx}])
    bodyHealth.take_damage(ctx)
    bodyHealth.event_manager.emit_event("after_take_damage", [{"damage_context": ctx}])
    if event_manager:
        event_manager.emit_event("after_deal_damage", [{"projectile": self, "body": body, "damage_context": ctx}])
    if event_manager:
        event_manager.emit_event("on_hit", [{"explosion": self, "body": body, "damage_context": ctx}])  
