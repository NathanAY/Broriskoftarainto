extends Node
class_name ExplosiveShotModifier

@export var display_name: String = "Explosive Shot"
@export_multiline var tooltip_text: String = "Hits explode, dealing area damage."
@export var trigger_event: String = "on_hit"
@export var damage_multiplier_per_stack: float = 0.5 # +50% explosion damage per stack

var explosionScene = preload("res://src/scenes/Explosion.tscn")

var explosion_radius := 64.0
var explosion_damage := 3.0

var event_manager: EventManager = null
var stacks: Array[bool] = []  # each entry = active/inactive

func get_tooltip_stats() -> String:
    return "Explodes for %s damage, +%d%% per stack" % [str(explosion_damage), int(round(damage_multiplier_per_stack * 100.0))]

func _active_stacks() -> int:
    return max(1, stacks.count(true))

func add_stack(active: bool):
    stacks.append(active)

func remove_stack(index: int):
    if index >= 0 and index < stacks.size():
        stacks.remove_at(index)

func set_stack_active(index: int, active: bool):
    if index >= 0 and index < stacks.size():
        stacks[index] = active

func attachEventManager(em: Node):
    event_manager = em
    event_manager.subscribe(trigger_event, Callable(self, "_on_hit"))
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
    explosion.damage = explosion_damage * (1.0 + (damage_multiplier_per_stack * (_active_stacks() - 1)))
    get_tree().current_scene.add_child(explosion)

func _on_stat_changes(event: Dictionary):
    var stat_name: String = event.get("stat_name", "")
    var value: float = event.get("final_value", 0.0)
    match stat_name:
        "damage":
            explosion_damage = value