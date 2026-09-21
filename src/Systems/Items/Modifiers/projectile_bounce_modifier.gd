extends Node
class_name ProjectileBounceModifier

@export var display_name: String = "Projectile Bounce"
@export var max_bounces: int = 3
@export var bounce_range: float = 1000.0

var holder: Node
var event_manager: EventManager
var stacks: Array[bool] = []

func get_tooltip_stats() -> String:
    return "Projectiles bounce to %d extra targets per stack" % max_bounces

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
    holder = em.get_parent()
    em.subscribe("on_attack", Callable(self, "_on_attack"))

func _on_attack(data: Dictionary):
    if !data.has("projectile"):
        return
    var projectile: Projectile = data["projectile"]

    var active_count = _active_stacks()
    for i in range(active_count):
        var bounce = preload("res://src/Systems/weapon/projectile_bounce_behavior.gd").new()
        bounce.holder = holder
        bounce.max_bounces = max_bounces
        bounce.bounce_range = bounce_range
        bounce.target_selector = data.get("weapon", null).target_selector if data.has("weapon") else null
        projectile.add_child(bounce)