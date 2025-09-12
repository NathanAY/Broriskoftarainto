# Explosion.gd
extends Area2D

@export var radius: float = 100.0
@export var damage: int = 20
@export var duration: float = 0.15
var time_passed: float = 0.0
var event_manager: EventManager = null 

func _ready():
    #radius = $CollisionShape2D.shape.radius
    $CollisionShape2D.shape.radius = radius
    connect("body_entered", Callable(self, "_on_body_entered"))

func attachEventManager(em: EventManager):
    event_manager = em

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
        var health_node: Health = body.get_node("Health")
        health_node.take_damage(damage)
    else:
        print("Explosion.gd: Body has no Health node!")
    if event_manager:
        event_manager.emit_event("on_hit", [{"explosion": self, "body": body}])        
