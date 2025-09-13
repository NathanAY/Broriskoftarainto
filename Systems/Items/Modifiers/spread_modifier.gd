# SpreadModifier.gd
extends Node

#@export var projectile_scene: PackedScene
@export var projectile_scene = preload("res://Systems/weapon/Projectile.tscn")
var event_manager: EventManager
var stacks: int = 0  # number of items picked up

func attachEventManager(em: EventManager):
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
    if event.get("item").resource_path.ends_with("SpreadShot.tres"):
        stacks = max(0, stacks - 1)
    pass

func _on_stat_changes(data):
    print("SpreadModifier: unimplemented _on_stat_changes")
    pass

#func _on_tower_attack(projectile: Node):
func _on_attack(data: Dictionary):
    if !data.has("projectile"):
        return
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
        # Pass the source projectile so we can copy values
        _spawn_extra(projectile, left_angle, damage)
        _spawn_extra(projectile, right_angle, damage)

func _spawn_extra(source: Node, direction: Vector2, damage: float):
    var p: Projectile = projectile_scene.instantiate()
    
    # Copy key values
    p.damage = damage
    p.base_speed = source.base_speed
    p.ignore_groups = source.ignore_groups.duplicate()
    p.attachEventManager(event_manager)
    p.global_position = source.global_position
    if p.has_method("set_direction"):
        p.set_direction(direction)
    get_tree().current_scene.add_child(p)
    
