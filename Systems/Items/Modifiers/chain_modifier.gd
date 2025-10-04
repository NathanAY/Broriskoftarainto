extends Node
class_name ChainModifier

@export var projectile_scene: PackedScene
@export var target_selector: TargetSelector
@export var max_bounces: int = 3
@export var bounce_range: float = 1000
@export var projectile_speed: float = 2000
@export var trigger_event: String = "on_hit" #"on_attack", "on_hit", "before_take_damage"

var event_manager: EventManager = null
var holder: Node
var stats: Stats
var ignore_groups: Array = []
var modifier_meta = "spawned_by_ChainModifier"

func attachEventManager(em: EventManager):
    event_manager = em
    holder = em.get_parent()
    stats = holder.get_node("Stats")
    ignore_groups = holder.get_groups().filter(func(g): return g != "damageable")
    em.subscribe(trigger_event, Callable(self, "_on_triger"))

func _on_triger(event: Dictionary) -> void:
    # Skip if this projectile was already spawned by this modifier
    if event.has("projectile"):
        var projectile: Projectile = event["projectile"]
        if projectile.get_meta(modifier_meta, false):
            return

    var damage: int = 0
    var spawn_position: Vector2
    if event.has("damage_context"):
        var damage_ctx: DamageContext = event["damage_context"]
        if damage_ctx.target != holder: 
            spawn_position = damage_ctx.target.global_position
        damage = max(damage_ctx.base_amount, damage_ctx.final_amount)
    elif event.has("weapon"):
        var weapon: BaseWeapon = event["weapon"]
        damage = weapon.base_damage
    if damage == 0:
        damage = stats.get_stat("damage")

    if !spawn_position:
        spawn_position = holder.global_position

    var ignore_enemy: Node = null
    if event.has("body"):
        ignore_enemy = event["body"]

    var next_target = _find_next_target(ignore_enemy)
    call_deferred("_spawn_chain_projectile", damage, spawn_position, next_target, ignore_enemy)


func _find_next_target(exclude: Node) -> Node:
    if not target_selector:
        return null
    var holder_node = holder
    if not holder_node:
        return null
    var sprite_node: Node2D = holder_node.get_node_or_null("Sprite") if holder_node else null
    if not sprite_node:
        sprite_node = holder_node
    var candidates = target_selector.find_targets(sprite_node, bounce_range, holder_node)
    candidates = candidates.filter(func(t): return t != exclude)
    return candidates[0] if candidates.size() > 0 else null

func _spawn_chain_projectile(damage: int, spawn_position: Vector2, next_target: Node2D, ignore_enemy: Node) -> void:
    var new_projectile: Projectile = projectile_scene.instantiate()
    new_projectile.damage = damage
    new_projectile.base_speed = projectile_speed
    new_projectile.ignore_groups = ignore_groups
    new_projectile.attachEventManager(event_manager)
    new_projectile.global_position = spawn_position
    
    var dir: Vector2
    if next_target:
        dir = (next_target.global_position - spawn_position).normalized()
    else:
        dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
    new_projectile.set_direction(dir)
    new_projectile.set_target(next_target)
    new_projectile.set_meta(modifier_meta, true)

    var bounce = preload("res://Systems/weapon/projectile_bounce_behavior.gd").new()
    bounce.holder = holder
    bounce.max_bounces = max_bounces
    bounce.bounce_range = bounce_range
    bounce.target_selector = target_selector

    # ✅ seed history with last two: previous and current
    if ignore_enemy:
        bounce.hit_history.append(ignore_enemy)  # the last hit
    if next_target:
        bounce.hit_history.append(next_target)   # the current chain target
    new_projectile.add_child(bounce)
    get_tree().current_scene.add_child(new_projectile)
