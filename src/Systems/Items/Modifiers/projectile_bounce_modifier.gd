extends BaseModifier

@export var display_name: String = "Projectile Bounce"
@export var trigger_event: String = "on_attack"
@export var max_bounces: int = 3
@export var bounce_range: float = 1000.0

func get_tooltip_stats() -> String:
    return "Projectiles bounce to %d extra targets per stack" % max_bounces

func attachEventManager(em: EventManager):
    _cache_holder(em)
    em.subscribe(trigger_event, Callable(self, "_on_attack"))

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