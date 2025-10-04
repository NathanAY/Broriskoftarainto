extends Node
class_name SpreadModifier

@export var projectile_scene = preload("res://Systems/weapon/Projectile.tscn")

var event_manager: EventManager
var stacks: Array[bool] = []  # each entry = active/inactive

func attachEventManager(em: EventManager):
    event_manager = em
    em.subscribe("on_attack", Callable(self, "_on_attack"))

func add_stack(active: bool):
    stacks.append(active)
    prints("add_stack", stacks)

func remove_stack(index: int):
    if index >= 0 and index < stacks.size():
        stacks.remove_at(index)
    prints("remove_stack", stacks)

func set_stack_active(index: int, active: bool):
    if index >= 0 and index < stacks.size():
        stacks[index] = active
    prints("set_stack_active", stacks)

func _on_attack(data: Dictionary):
    if !data.has("projectile"):
        return
    var projectile = data["projectile"]
    var damage = projectile.damage

    if not projectile_scene:
        push_warning("SpreadModifier: projectile_scene not assigned!")
        return

    var base_direction = projectile.direction
    var active_count = stacks.count(true)  # ✅ only active stacks

    for i in range(active_count):
        var angle = 10
        var left_angle = base_direction.rotated(deg_to_rad(-angle * (i + 1)))
        var right_angle = base_direction.rotated(deg_to_rad(angle * (i + 1)))
        _spawn_extra(projectile, left_angle, damage)
        _spawn_extra(projectile, right_angle, damage)

func _spawn_extra(source: Projectile, direction: Vector2, damage: float):
    var p: Projectile = projectile_scene.instantiate()
    p.damage = damage
    p.base_speed = source.base_speed
    p.ignore_groups = source.ignore_groups.duplicate()
    p.attachEventManager(event_manager)
    p.global_position = source.global_position
    if p.has_method("set_direction"):
        p.set_direction(direction)
        p.set_target(source.target)
    get_tree().current_scene.add_child(p)
