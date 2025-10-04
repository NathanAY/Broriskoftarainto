extends Node
class_name BossSpawner

@export var character: Character
@export var spawn_active: bool = false
@export var boss_scene: PackedScene = preload("res://Systems/EnemyBoss.tscn")
@export var current_loop: int = 1
@export var health_growth_per_loop: float = 500
@export var damage_growth_per_loop: float = 30

var enemiesNode: Node = null
var boss_instance: Enemy = null

func _ready():
    enemiesNode = get_node("../../Nodes/Enemies")

func spawn_boss():
    if boss_instance and is_instance_valid(boss_instance):
        return # already spawned

    boss_instance = boss_scene.instantiate()
    var character_position: Vector2 = character.global_position
    var angle = randf_range(0, TAU)
    var radius = 700.0
    var spawn_position = character_position + Vector2(cos(angle), sin(angle)) * radius
    boss_instance.global_position = spawn_position
    
    enemiesNode.add_child(boss_instance)

    # Apply loop-based scaling
    _apply_scaling(boss_instance)

    if boss_instance.has_method("set_target_position"):
        boss_instance.set_target_position(character)
    
    print("Boss spawned!")

func _apply_scaling(boss_instance: Enemy) -> void:
    var stats = boss_instance.get_node_or_null("Stats")
    if not stats:
        return
    # Scale only by stage
    var extra_health = health_growth_per_loop * (current_loop)
    var extra_damage = damage_growth_per_loop * (current_loop)
    stats.set_base_stat("health", stats.stats["health"] + extra_health)
    stats.set_base_stat("damage", stats.stats["damage"] + extra_damage)
    
    #boss_instance.item_holder.add_item(load("res://Resources/items/HealthMeat.tres"))
    for i in current_loop:
        boss_instance.weapon_holder.add_weapon(load("res://Resources/weapons/Fist.tres"))
        boss_instance.weapon_holder.add_weapon(load("res://Resources/weapons/Fist.tres"))
        if i == 2:
            boss_instance.weapon_holder.add_weapon(load("res://Resources/weapons/Pistol.tres"))
            boss_instance.weapon_holder.add_weapon(load("res://Resources/weapons/Pistol.tres"))
        if i == 3:
            boss_instance.item_holder.add_item(load("res://Resources/items/SpreadShot.tres"))

    boss_instance.health_node.heal(1000000)
