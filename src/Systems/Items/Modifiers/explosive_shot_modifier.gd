extends BaseModifier

@export var display_name: String = "Explosive Shot"
@export_multiline var tooltip_text: String = "Hits explode, dealing area damage."
@export var trigger_event: String = "on_hit"
@export var damage_multiplier_per_stack: float = 0.5 # +50% explosion damage per stack

var explosion_scene = preload("res://src/Scenes/Explosion.tscn")

var explosion_radius := 64.0
var explosion_damage := 3.0

func get_tooltip_stats() -> String:
    return "Explodes for %s damage, +%d%% per stack" % [str(explosion_damage), int(round(damage_multiplier_per_stack * 100.0))]

func attachEventManager(em: Node):
    _cache_holder(em)
    event_manager.subscribe(trigger_event, Callable(self, "_on_hit"))

func _on_hit(event: Dictionary):
    if !event.has("projectile"):
        return
    var projectile = event["projectile"]
    # Defer the explosion spawn to avoid flushing query errors
    call_deferred("_spawn_explosion", projectile.global_position)

func _spawn_explosion(position: Vector2):
    var explosion = explosion_scene.instantiate()
    explosion.attachEventManager(event_manager)
    explosion.global_position = position
    explosion.radius = explosion_radius
    explosion.damage = explosion_damage * (1.0 + (damage_multiplier_per_stack * (_active_stacks() - 1)))
    get_tree().current_scene.add_child(explosion)