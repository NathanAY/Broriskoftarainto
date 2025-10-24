#ExplosiveShotEffect
extends Node

var explosionScene = preload("res://scenes/Explosion.tscn")

var explosion_radius := 64.0
var explosion_damage := 3

var event_manager: EventManager = null 

func attachEventManager(em: Node):
    print("ExplosiveShotEffect: attachEventManager")
    event_manager = em
    event_manager.subscribe("on_hit", Callable(self, "_on_hit"))
    event_manager.subscribe("on_stat_changes", Callable(self, "_on_stat_changes"))

func _on_hit(event: Dictionary):
    if !event.has("projectile"):
        return
    var projectile = event["projectile"]
    # Defer the explosion spawn to avoid flushing query errors
    call_deferred("_spawn_explosion", projectile.global_position)

func _spawn_explosion(position: Vector2):
    var explosion = explosionScene.instantiate()
    explosion.attachEventManager(event_manager)
    explosion.global_position = position
    explosion.radius = explosion_radius
    explosion.damage = explosion_damage
    get_tree().current_scene.add_child(explosion)

func _on_stat_changes(stat_name: String, value: float):
    match stat_name:
        "damage":
            explosion_damage = value
            print("ExplosiveShotEffect: explosion damage updated ->", value)
