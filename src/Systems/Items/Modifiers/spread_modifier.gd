extends Node
class_name SpreadModifier

@export var projectile_scene = preload("res://src/Systems/weapon/Projectile.tscn")

@export var display_name: String = "Spread"
@export var trigger_event: String = "on_attack"

var event_manager: EventManager
var stacks: Array[bool] = []  # each entry = active/inactive

func get_tooltip_stats() -> String:
    return "Spawns 2 extra projectiles per stack"

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

func attachEventManager(em: EventManager):
    event_manager = em
    em.subscribe("on_attack", Callable(self, "_on_attack"))

func _on_attack(data: Dictionary):
    if !data.has("projectile"):
        return
    var projectile = data["projectile"]
    var damage = projectile.damage

    if not projectile_scene:
        push_warning("SpreadModifier: projectile_scene not assigned!")
        return

    var base_direction = projectile.direction
    var active_count = _active_stacks()  # only active stacks

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