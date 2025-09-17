# HomingModifier.gd
extends Node

@export var homing_strength: float = 2.0   # how fast projectile can turn (radians per second)
@export var homing_range: float = 400.0    # max distance to search for targets

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
        var homing = preload("res://Systems/weapon/homing_behavior.gd").new()
        homing.holder = holder
        homing.homing_strength = homing_strength
        homing.homing_range = homing_range
        projectile.add_child(homing)
