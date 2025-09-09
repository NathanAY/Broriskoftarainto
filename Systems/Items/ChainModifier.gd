# ChainModifier.gd
extends Node

#@export var projectile_scene: PackedScene
@export var projectile_scene = preload("res://Scenes/Projectile.tscn")
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var event_manager = null

func attachEventManager(em: Node):
    event_manager = em
    em.subscribe("projectile_hit", Callable(self, "_on_projectile_hit"))

func _ready():
    rng.randomize()

func _on_projectile_hit(projectile, body):
    #print("ChainModifier: _on_projectile_hit -> projectile:", projectile, " body:", body)
    if not body or not body.is_in_group("enemies"):
        print("ChainModifier: hit body is not an enemy")
        return
    #var enemies = get_tree().get_nodes_in_group("enemies")
    var enemies = get_tree().get_nodes_in_group("enemies").filter(func(e): return e != body)
    var target_pos: Vector2
    if enemies.size() == 0:
        var angle = rng.randf_range(0, TAU)
        var dir = Vector2.RIGHT.rotated(angle)
        target_pos = projectile.global_position + dir * 1000 # arbitrary far away point
    else:
        target_pos = enemies.pick_random().global_position
    # ensure projectile_scene exported in inspector
    if not projectile_scene:
        print("ChainModifier: projectile_scene not assigned!")
        return
    #TODO fix a Invalid access to property or key 'global_position' on a base object of type 'Vector2'.    
    #if next_target != body:
    call_deferred("_spawn_chain_projectile", projectile.global_position, target_pos, body, projectile.damage)


func _spawn_chain_projectile(from: Vector2, to: Vector2, ignore_enemy: Node, damage: float) -> void:
    #print("ChainModifier: _spawn_chain_projectile ")
    var new_projectile = projectile_scene.instantiate()
    new_projectile.damage = damage
    new_projectile.set_event_manager(event_manager)
    new_projectile.global_position = from

    if new_projectile.has_method("set_direction"):
        var dir = (to - from).normalized()
        new_projectile.set_direction(dir)

    new_projectile.set_meta("ignore_enemy", ignore_enemy.get_path())
    new_projectile.set_meta("spawned_by_chain", true)

    get_tree().current_scene.add_child(new_projectile)
    #print("ChainModifier: spawned chained projectile ", new_projectile)
