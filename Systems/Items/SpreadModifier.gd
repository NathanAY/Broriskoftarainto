# SpreadModifier.gd
extends Node

#@export var projectile_scene: PackedScene
@export var projectile_scene = preload("res://Scenes/Projectile.tscn")
var event_manager
var stacks: int = 0  # number of items picked up

func attachEventManager(em: Node):
    event_manager = em
    em.subscribe("on_attack", Callable(self, "_on_attack"))
    em.subscribe("on_stat_changes", Callable(self, "_on_stat_changes"))
    em.subscribe("on_item_added", Callable(self, "_on_item_added"))
    em.subscribe("on_item_removed", Callable(self, "_on_item_removed"))

func change_stack(amount: int):
    stacks += 0

func _on_item_added(event):
    if event.get("item").resource_path.ends_with("SpreadShot.tres"):
        stacks += 1
    pass

func _on_item_removed(event):
    #if event.get("item").resource_path.ends_with("SpreadShot.tres"):
        #stacks = max(0, stacks - 1)
    pass

func _on_stat_changes(data):
    print("SpreadModifier: Unimplemented")
    pass

#func _on_tower_attack(projectile: Node):
func _on_attack(data):
    var projectile = data["projectile"]
    var damage = projectile.damage
    
    #print("SpreadModifier: _on_attack")
    # Spawn two extra projectiles with angle offsets
    if not projectile_scene:
        push_warning("SpreadModifier: projectile_scene not assigned!")
        return
    var base_direction = projectile.direction
    for i in range(stacks):
        #var angle = randi_range(3, 60);
        var angle = 10;
        var left_angle = base_direction.rotated(deg_to_rad(-angle * (i + 1)))
        var right_angle = base_direction.rotated(deg_to_rad(angle * (i + 1)))
        _spawn_extra(projectile.global_position, left_angle, damage)
        _spawn_extra(projectile.global_position, right_angle, damage)

func _spawn_extra(from: Vector2, direction: Vector2, damage: float):
    var p = projectile_scene.instantiate()
    p.damage = damage
    p.set_event_manager(event_manager)
    p.global_position = from
    if p.has_method("set_direction"):
        p.set_direction(direction)
    get_tree().current_scene.add_child(p)
