extends Node2D
class_name KnockbackController

var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
var knockback_duration: float = 0.0

func start_knockback(force: Vector2, duration: float):
    knockback_velocity = force
    knockback_duration = duration
    knockback_timer = duration

func _physics_process(delta: float) -> void:
    if knockback_timer > 0:
        knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, delta * 5.0)
        get_parent().global_position += knockback_velocity * delta
        knockback_timer -= delta
    else:
        knockback_velocity = Vector2.ZERO
        queue_free()
