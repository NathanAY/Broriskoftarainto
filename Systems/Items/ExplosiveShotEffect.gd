#ExplosiveShotEffect
extends Node

var explosion_radius := 64.0
var explosion_damage := 4

func attachEventManager(event_manager: Node):
    print("ExplosiveShotEffect: attachEventManager")
    event_manager.subscribe("projectile_hit", Callable(self, "_on_projectile_hit"))
    event_manager.subscribe("on_stat_changes", Callable(self, "_on_stat_changes"))

func _on_projectile_hit(projectile, body):
    print("ExplosiveShotEffect: _on_hit")
    # Defer the explosion spawn to avoid flushing query errors
    call_deferred("_spawn_explosion", projectile.global_position)

func _spawn_explosion(position: Vector2):
    var explosion = preload("res://scenes/Explosion.tscn").instantiate()
    explosion.global_position = position
    explosion.radius = explosion_radius
    explosion.damage = explosion_damage
    get_tree().current_scene.add_child(explosion)

func _on_stat_changes(stat_name: String, value: float):
    match stat_name:
        "area_size":
            explosion_radius = value
            print("ExplosiveShotEffect: explosion radius updated ->", value)
        "damage":
            explosion_damage = value
            print("ExplosiveShotEffect: explosion damage updated ->", value)
