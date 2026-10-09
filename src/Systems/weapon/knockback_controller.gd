extends Node2D
class_name KnockbackController

## This is the conversion boundary. Callers hold `knockback_strength` in
## meters per second, the unit a `.tres` and the tooltip both use; the decay
## below integrates a velocity against a delta, so it has to be pixels per
## second. Nothing downstream of `start_knockback` knows about meters.
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
var knockback_duration: float = 0.0

## `force` is a velocity in meters per second; `direction` is expected to be a
## unit vector, which the callers all normalize before getting here.
func start_knockback(force: Vector2, duration: float):
    knockback_velocity = Stats.meters_to_px(force.length()) * force.normalized()
    knockback_duration = duration
    knockback_timer = duration

func _physics_process(delta: float) -> void:
    if knockback_timer > 0:
        knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, delta * 5.0)
        # move_and_collide (not raw position +=) so knockback stops at arena
        # walls instead of pushing bodies through the end of the ground.
        var parent := get_parent()
        if parent is PhysicsBody2D:
            (parent as PhysicsBody2D).move_and_collide(knockback_velocity * delta)
        else:
            parent.global_position += knockback_velocity * delta
        knockback_timer -= delta
    else:
        knockback_velocity = Vector2.ZERO
        queue_free()
