extends BaseModifier

@export var projectile_scene: PackedScene
@export var target_selector: TargetSelector
@export var homing_strength: float = 2.0
@export var homing_range: int = 600
@export var projectile_speed: int = 250
@export var life_time: int = 5
@export var display_name: String = "Homing Rocket"
@export var trigger_event: String = "before_take_damage" #"on_attack", "on_hit", "before_take_damage"

func get_tooltip_stats() -> String:
    return "Launches a homing rocket dealing 100% of hit damage (+1 per stack)"

var modifier_meta = "spawned_by_HomingRocketModifier"
var ignore_groups: Array = []
var _current_projectile_speed_multiplier: float = 1

func attachEventManager(em: EventManager):
    _cache_holder(em)
    ignore_groups = holder.get_groups().filter(func(g): return g != "damageable")
    event_manager.subscribe(trigger_event, Callable(self, "_on_trigger"))
    event_manager.subscribe("on_stat_changes", Callable(self, "_on_stat_changes"))

func _on_trigger(event: Dictionary) -> void:
    if _is_own_projectile(event):
        return
    var damage: float = _extract_damage(event)
    var target: Node2D = _extract_target(event)
    for i in range(_active_stacks()):
        call_deferred("_spawn_homing_projectile", holder, damage, target)

## Shared with homing_rocket_from_target modifier (subclass).
func _is_own_projectile(event: Dictionary) -> bool:
    if event.has("projectile"):
        var projectile: Projectile = event["projectile"]
        return projectile.get_meta(modifier_meta, false)
    return false

## Shared with homing_rocket_from_target modifier (subclass).
func _extract_damage(event: Dictionary) -> float:
    var damage: float = 0.0
    if event.has("damage_context"):
        var damage_ctx: DamageContext = event["damage_context"]
        damage = max(damage_ctx.base_amount, damage_ctx.final_amount)
    elif event.has("weapon"):
        var weapon: BaseWeapon = event["weapon"]
        damage = weapon.base_damage
    if damage == 0:
        damage = stats.get_stat("damage")
    return damage

## Subclass overrides this to also consider damage_context.source.
func _extract_target(event: Dictionary) -> Node2D:
    if event.has("damage_context"):
        var damage_ctx: DamageContext = event["damage_context"]
        if damage_ctx.target != holder:
            return damage_ctx.target
    return null

## Shared with homing_rocket_from_target modifier (subclass): picks the next
## enemy within homing_range, excluding the given node.
func _find_next_target(exclude: Node) -> Node:
    if not target_selector or not holder:
        return null
    var sprite_node: Node2D = holder.get_node_or_null("Sprite")
    if not sprite_node:
        sprite_node = holder
    var candidates = target_selector.find_targets(sprite_node, homing_range, holder)
    candidates = candidates.filter(func(t): return t != exclude)
    return candidates[0] if candidates.size() > 0 else null

func _spawn_homing_projectile(source: Node, damage: int, next_target: Node2D) -> void:
    var new_projectile: Projectile = projectile_scene.instantiate()
    new_projectile.damage = damage
    new_projectile.base_speed = projectile_speed * _current_projectile_speed_multiplier
    new_projectile.ignore_groups = ignore_groups
    new_projectile.life_time = life_time
    new_projectile.attachEventManager(event_manager)
    new_projectile.global_position = source.global_position

    var random_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
    new_projectile.set_direction(random_dir)
    new_projectile.set_target(next_target)
    new_projectile.set_meta(modifier_meta, true)
    new_projectile.set_meta("ignore_enemy", source)

    # Add homing behavior
    var homing = preload("res://src/Systems/weapon/homing_behavior.gd").new()
    homing.holder = holder
    homing.homing_strength = homing_strength
    homing.homing_range = homing_range
    new_projectile.add_child(homing)
    get_tree().current_scene.add_child(new_projectile)

func _on_stat_changes(_event) -> void:
    _current_projectile_speed_multiplier = stats.get_stat("projectile_speed_multiplier")