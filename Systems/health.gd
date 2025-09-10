# Health.gd
extends Node
class_name Health

var max_health: float = 50
var current_health: float

@onready var stats: Stats = get_parent().get_node_or_null("Stats")
@export var event_manager: EventManager = null  # assign LocalEventManager if needed

func _ready():
    event_manager.subscribe("on_stat_changes", Callable(self, "_update_max_health"))
    max_health = stats.get_stat("health")
    current_health = max_health

func take_damage(amount: float) -> void:
    current_health -= amount
    _emit_on_health_changed_event(-amount)
    if current_health <= 0:
        die()

func heal(amount: float) -> void:
    current_health = min(current_health + amount, max_health)
    _emit_on_health_changed_event(amount)
    if event_manager:
        event_manager.emit_event("on_heal", [{"self":get_parent(),
        "amount":amount, "current_health": current_health, "max_health": max_health}])

func die() -> void:
    if event_manager:
        event_manager.emit_event("on_death", [self.get_parent()])
    # Optionally remove owner node
    get_parent().queue_free()

func _update_max_health():
    max_health = stats.get_stat("health")
    _emit_on_health_changed_event(0)

func _emit_on_health_changed_event(amount: float):
    if event_manager:
        event_manager.emit_event("on_health_changed", [{"self":self.get_parent(),
        "amount":amount, "current_health": current_health, "max_health": max_health}])
