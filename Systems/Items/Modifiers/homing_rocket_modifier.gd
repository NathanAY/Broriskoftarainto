extends Node
class_name HomingOnHitModifier

@export var projectile_scene: PackedScene
@export var target_selector: TargetSelector
@export var homing_strength: float = 2.0
@export var homing_range: int = 600
@export var projectile_speed: int = 250
@export var life_time: int = 5
@export var trigger_event: String = "before_take_damage" #"on_attack", "on_hit", "before_take_damage"

var modifier_meta = "spawned_by_HomingOnHitModifier"
var event_manager: EventManager
var holder: Node
var stats: Stats
var ignore_groups: Array = []
var stacks: Array[bool] = []

func attachEventManager(em: EventManager):
    event_manager = em
    holder = em.get_parent()
    stats = holder.get_node("Stats")
    ignore_groups = holder.get_groups().filter(func(g): return g != "damageable")
    em.subscribe(trigger_event, Callable(self, "_on_triger"))

func add_stack(active: bool):
    stacks.append(active)

func remove_stack(index: int):
    if index >= 0 and index < stacks.size():
        stacks.remove_at(index)

func set_stack_active(index: int, active: bool):
    if index >= 0 and index < stacks.size():
        stacks[index] = active

func _on_triger(event: Dictionary) -> void:
    # Skip if this projectile was already spawned by this modifier
    if event.has("projectile"):
        var projectile: Projectile = event["projectile"]
        if projectile.get_meta(modifier_meta, false):
            return

    var target = null
    var damage: int = 0
    if event.has("damage_context"):
        var damage_ctx: DamageContext = event["damage_context"]
        damage = max(damage_ctx.base_amount, damage_ctx.final_amount)
        if damage_ctx.target != holder: 
            target = damage_ctx.target
    elif event.has("weapon"):
        var weapon: BaseWeapon = event["weapon"]
        damage = weapon.base_damage

    if damage == 0:
        damage = stats.get_stat("damage")

    var active_count = stacks.count(true)
    if active_count == 0:
        return

    if target:
        call_deferred("_spawn_homing_projectile", holder, damage, target)
    else:
        call_deferred("_spawn_homing_projectile", holder, damage, null)

func _spawn_homing_projectile(source: Node, damage: int, next_target: Node2D) -> void:
    var new_projectile: Projectile = projectile_scene.instantiate()
    new_projectile.damage = damage
    new_projectile.base_speed = projectile_speed
    new_projectile.ignore_groups = ignore_groups
    new_projectile.life_time = life_time
    new_projectile.attachEventManager(event_manager)
    new_projectile.global_position = source.global_position

    var random_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
    new_projectile.set_direction(random_dir)
    new_projectile.set_target(next_target)
    new_projectile.set_meta(modifier_meta, true)

    # ✅ Add homing behavior
    var homing = preload("res://Systems/weapon/homing_behavior.gd").new()
    homing.holder = holder
    homing.homing_strength = homing_strength
    homing.homing_range = homing_range
    new_projectile.add_child(homing)
    get_tree().current_scene.add_child(new_projectile)
