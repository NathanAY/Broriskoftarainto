# Health.gd
extends Node
class_name Health

var max_health: float = 50
var current_health: float
## Latched the moment the entity dies. A dead entity keeps living in the tree for
## the whole death animation, so every damage source has to be turned away until
## the owner is actually freed - otherwise the corpse keeps losing health and
## keeps re-emitting the hit/death events that drive the visual effect managers.
var is_dead: bool = false

@onready var stats: Stats = get_parent().get_node_or_null("Stats")
@export var event_manager: EventManager = null  # assign LocalEventManager if needed

func _ready():
    event_manager.subscribe("on_stat_changes", Callable(self, "_update_max_health"))
    max_health = stats.get_stat("health")
    current_health = max_health

## The single entry point for dealing damage, and the only place the dead check
## lives. It owns the whole defender phase of the pipeline
## (`before_take_damage` -> damage -> `on_death` -> `after_take_damage`) so a
## caller cannot skip the guard, and so nothing downstream of a rejected hit
## fires: no `HitFlashManager` flash, no `ParticleEffectManager` particles, no
## `TextureBurstManager` burst, no `on_kill` rewards.
## Returns true when the damage was actually applied.
func apply_damage(damage_context: DamageContext) -> bool:
    if is_dead:
        return false
    if event_manager:
        event_manager.emit_event("before_take_damage", {"damage_context": damage_context})
    if is_dead:
        # A `before_take_damage` listener (reflect, execute, ...) may have killed
        # the entity outright, so the hit still has to be dropped.
        return false
    current_health -= damage_context.final_amount
    _emit_on_health_changed_event(-damage_context.final_amount)
    damage_context.target_take_persent_damage = damage_context.final_amount / max_health
    if current_health <= 0:
        die(damage_context)
    if event_manager:
        event_manager.emit_event("after_take_damage", {"damage_context": damage_context})
    return true

func heal(amount: float) -> void:
    current_health = min(current_health + amount, max_health)
    _emit_on_health_changed_event(amount)
    if event_manager:
        event_manager.emit_event("on_heal", {"self":get_parent(),
        "amount":amount, "current_health": current_health, "max_health": max_health})

func die(damage_context: DamageContext) -> void:
    if is_dead:
        return
    # Latch before emitting: an `on_death` listener may deal damage back, and that
    # damage must be rejected just like any later hit.
    is_dead = true
    if event_manager:
        event_manager.emit_event("on_death", {"self": self.get_parent(), "damage_context": damage_context})

func _update_max_health(_event):
    max_health = stats.get_stat("health")
    _emit_on_health_changed_event(0)

func _emit_on_health_changed_event(amount: float):
    if event_manager:
        event_manager.emit_event("on_health_changed", {"self":self.get_parent(),
        "amount":amount, "current_health": current_health, "max_health": max_health})
