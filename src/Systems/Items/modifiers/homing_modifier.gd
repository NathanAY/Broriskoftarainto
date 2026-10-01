extends BaseModifier

@export var display_name: String = "Homing"
@export var homing_strength: float = 1.0   # how fast projectile can turn (radians per second)
@export var homing_range: float = 400.0    # max distance to search for targets
@export var trigger_event: String = "on_attack"

func get_tooltip_stats() -> String:
    return "Projectiles seek targets within %s" % str(homing_range)

func attachEventManager(em: EventManager):
    _cache_holder(em)
    event_manager.subscribe(trigger_event, Callable(self, "_on_attack"))

func _on_attack(data: Dictionary):
    if !data.has("projectile"):
        return
    var projectile: Projectile = data["projectile"]

    var active_count = _active_stacks()
    for i in range(active_count):
        var homing = preload("res://src/Systems/weapon/homing_behavior.gd").new()
        homing.holder = holder
        homing.homing_strength = homing_strength
        homing.homing_range = homing_range
        projectile.add_child(homing)