extends BaseModifier

@export var projectile_scene: PackedScene
@export var target_selector: TargetSelector
@export var reflect_range: float = 250
@export var projectile_speed: float = 2000
@export var display_name: String = "Reflect Projectiles"
@export var volley_projectile_count: int = 2
@export var trigger_event: String = "before_take_damage"

func get_tooltip_stats() -> String:
    return "Fires %d projectiles back at attackers (+1 per stack)" % volley_projectile_count

var modifier_meta := "spawned_by_ReflectProjectileModifier"
var ignore_groups: Array = []
var _current_projectile_speed_multiplier: float = 1.0
var _current_damage_multiplier: float = 1.0

func attachEventManager(em: EventManager):
    _cache_holder(em)
    ignore_groups = holder.get_groups().filter(func(g): return g != "damageable")
    event_manager.subscribe(trigger_event, Callable(self, "_on_trigger"))
    event_manager.subscribe("on_stat_changes", Callable(self, "_on_stat_changes"))

func _on_trigger(_event: Dictionary) -> void:
    var active_stacks: int = _active_stacks()# +1 projectile per stack, bigger range

    var targets = target_selector.find_targets(holder, reflect_range * active_stacks, holder)
    if targets.is_empty():
        return
    var damage: float = stats.get_stat("base_damage") * _current_damage_multiplier
    var speed: int = int(projectile_speed * _current_projectile_speed_multiplier)
    # spawn volley toward each target
    for i in range(min(volley_projectile_count + (active_stacks - 1), targets.size())):
        var target = targets.get(i)
        call_deferred("_spawn_projectile", target, damage, speed)

func _spawn_projectile(target: Node2D, damage: float, speed: int):
    var projectile: Projectile = projectile_scene.instantiate()
    projectile.damage = damage
    projectile.base_speed = speed
    projectile.ignore_groups = ignore_groups
    projectile.attachEventManager(event_manager)
    projectile.global_position = holder.global_position
    projectile.set_target(target)
    projectile.set_meta(modifier_meta, true)

    # Add to scene
    get_tree().current_scene.add_child(projectile)

    # Slight random spread (optional)
    var spread_dir = null
    if target:
        spread_dir = (target.global_position - holder.global_position).normalized()
        spread_dir = spread_dir.rotated(deg_to_rad(randf_range(-10, 10)))
        projectile.set_direction(spread_dir)
    else:
        var random_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
        projectile.set_direction(random_dir)
    

func _on_stat_changes(_event):
    _current_projectile_speed_multiplier = stats.get_stat("projectile_speed_multiplier")
    _current_damage_multiplier = stats.get_stat("damage")