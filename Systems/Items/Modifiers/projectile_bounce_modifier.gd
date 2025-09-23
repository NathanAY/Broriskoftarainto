extends Node
class_name ProjectileBounceModifier

@export var max_bounces: int = 3
@export var bounce_range: float = 1000.0

var holder: Node
var event_manager: EventManager
var stacks: Array[bool] = []

func attachEventManager(em: EventManager):
    event_manager = em
    holder = em.get_parent()
    em.subscribe("on_attack", Callable(self, "_on_attack"))

func add_stack(active: bool):
    stacks.append(active)

func remove_stack(index: int):
    if index >= 0 and index < stacks.size():
        stacks.remove_at(index)

func set_stack_active(index: int, active: bool):
    if index >= 0 and index < stacks.size():
        stacks[index] = active

func _on_attack(data: Dictionary):
    if !data.has("projectile"):
        return
    var projectile: Projectile = data["projectile"]

    var active_count = stacks.count(true)
    for i in range(active_count):
        var bounce = preload("res://Systems/weapon/projectile_bounce_behavior.gd").new()
        bounce.holder = holder
        bounce.max_bounces = max_bounces
        bounce.bounce_range = bounce_range
        bounce.weapon = data.get("weapon", null)   # ✅ pass weapon for target_selector
        projectile.add_child(bounce)
