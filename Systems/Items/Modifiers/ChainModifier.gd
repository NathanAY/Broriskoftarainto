extends Node
class_name ChainModifier

@export var projectile_scene: PackedScene
@export var target_selector: TargetSelector
@export var max_bounces: int = 3
@export var bounce_range: float = 1000
@export var projectile_speed: float = 2000

var event_manager: EventManager = null
var holder: Node

func attachEventManager(em: EventManager):
    event_manager = em
    holder = em.get_parent()
    em.subscribe("on_hit", Callable(self, "_on_hit"))

func _on_hit(event: Dictionary) -> void:
    if !event.has("projectile") or !event.has("body"):
        return

    var projectile: Projectile = event["projectile"]
    if projectile.get_meta("spawned_by_chain", false):
        return
    var body: Node = event["body"]

    var next_target = _find_next_target(body)

    if next_target:
        call_deferred("_spawn_chain_projectile", projectile, next_target, body)
    else:
        # ⚡ fallback: random direction if no target found
        var random_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
        call_deferred("_spawn_chain_projectile_random", projectile, random_dir, body)

func _find_next_target(exclude: Node) -> Node:
    if not target_selector:
        return null

    var holder_node = holder
    if not holder_node:
        return null

    var sprite_node: Node2D = holder_node.get_node_or_null("Sprite") if holder_node else null
    if not sprite_node:
        sprite_node = holder_node

    var candidates = target_selector.find_targets(sprite_node, bounce_range, holder_node)
    candidates = candidates.filter(func(t): return t != exclude)

    return candidates[0] if candidates.size() > 0 else null

func _spawn_chain_projectile(source: Projectile, next_target: Node2D, ignore_enemy: Node) -> void:
    var new_projectile: Projectile = projectile_scene.instantiate()
    new_projectile.damage = source.damage
    new_projectile.base_speed = projectile_speed
    new_projectile.ignore_groups = source.ignore_groups.duplicate()
    new_projectile.attachEventManager(event_manager)
    new_projectile.global_position = source.global_position

    var dir = (next_target.global_position - source.global_position).normalized()
    new_projectile.set_direction(dir)
    new_projectile.set_target(next_target)

    new_projectile.set_meta("spawned_by_chain", true)

    var bounce = preload("res://Systems/weapon/projectile_bounce_behavior.gd").new()
    bounce.holder = holder
    bounce.max_bounces = max_bounces
    bounce.bounce_range = bounce_range
    bounce.target_selector = target_selector

    # ✅ seed history with last two: previous and current
    bounce.hit_history.append(ignore_enemy)  # the last hit
    bounce.hit_history.append(next_target)   # the current chain target

    new_projectile.add_child(bounce)

    get_tree().current_scene.add_child(new_projectile)


func _spawn_chain_projectile_random(source: Projectile, random_dir: Vector2, ignore_enemy: Node) -> void:
    var new_projectile: Projectile = projectile_scene.instantiate()
    new_projectile.damage = source.damage
    new_projectile.base_speed = projectile_speed
    new_projectile.ignore_groups = source.ignore_groups.duplicate()
    new_projectile.attachEventManager(event_manager)
    new_projectile.global_position = source.global_position

    new_projectile.set_direction(random_dir)

    new_projectile.set_meta("ignore_enemy", ignore_enemy.get_path())
    new_projectile.set_meta("spawned_by_chain", true)

    var bounce = preload("res://Systems/weapon/projectile_bounce_behavior.gd").new()
    bounce.holder = holder
    bounce.max_bounces = max_bounces
    bounce.bounce_range = bounce_range
    bounce.target_selector = target_selector   # ✅ inject directly

    # ✅ seed history with the last hit only
    bounce.hit_history.append(ignore_enemy)

    new_projectile.add_child(bounce)

    get_tree().current_scene.add_child(new_projectile)
