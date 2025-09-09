# Health.gd
extends Node

@export var max_health: float = 50
var current_health: float

@export var event_manager: Node = null  # assign LocalEventManager if needed

func _ready():
    current_health = max_health

func take_damage(amount: float) -> void:
    current_health -= amount
    if event_manager:
        event_manager.emit_event("on_take_damage", [{"self":self.get_parent(),
        "amount":amount, "current_health": current_health, "max_health": max_health}])
    if current_health <= 0:
        die()

func heal(amount: float) -> void:
    current_health = min(current_health + amount, max_health)

func die() -> void:
    if event_manager:
        event_manager.emit_event("on_death", [self.get_parent()])
    # Optionally remove owner node
    self.get_parent().queue_free()
