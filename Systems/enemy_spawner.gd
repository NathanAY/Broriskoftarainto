extends Node
class_name EnemySpawner

@export var character: Character
@export var spawn_interval = 3 #3 enemies per second if base_target_enemy_count == current number of enemies
@export var health_growth_per_loop: float = 20
@export var damage_growth_per_loop: float = 5
@export var base_target_enemy_count = 5 # initial target enemies per stage
@export var current_loop: int = 1
@export var spawn_active: bool = true

var enemy_scene = preload("res://Systems/Enemy.tscn")
var enemiesNode: Node = null
var modifiers: Array = []
var target_enemy_count: int
var spawn_timer: Timer = null

func _ready():
    spawn_timer = Timer.new()
    spawn_timer.wait_time = spawn_interval
    spawn_timer.one_shot = false
    spawn_timer.timeout.connect(_on_spawn_timer_timeout)
    add_child(spawn_timer)
    spawn_timer.start()
    enemiesNode = get_node("../../Nodes/Enemies")
    target_enemy_count = base_target_enemy_count
    for c in get_children():
        if c.has_method("attach_to_enemy"):
            modifiers.append(c)

func _on_spawn_timer_timeout():
    if spawn_active:
        spawn_enemy()
        _adjust_spawn_rate()
    else:
        # Stop spawning after stage time
        spawn_timer.stop()

func spawn_enemy():
    if not character:
        return
    
    var enemy = enemy_scene.instantiate()
    var character_position: Vector2 = character.global_position
    var angle = randf_range(0, TAU)
    var radius = 500.0
    var spawn_position = character_position + Vector2(cos(angle), sin(angle)) * radius
    enemy.global_position = spawn_position

    # Apply modifiers
    for mod in modifiers:
        mod.attach_to_enemy(enemy, character)
    
    # Apply stage-based scaling
    _apply_stage_scaling(enemy)
    
    enemiesNode.add_child(enemy)
    enemy.set_target_position(character)

func _apply_stage_scaling(enemy: Node) -> void:
    var stats = enemy.get_node_or_null("Stats")
    if not stats:
        return
    # Scale only by stage
    var extra_health = health_growth_per_loop * (current_loop - 1)
    var extra_damage = damage_growth_per_loop * (current_loop - 1)
    stats.set_base_stat("health", stats.stats["health"] + extra_health)
    stats.set_base_stat("damage", stats.stats["damage"] + extra_damage)

func _adjust_spawn_rate():
    var current_enemies = enemiesNode.get_child_count()
    var multiplier = 1.0
    if current_enemies < target_enemy_count:
        multiplier = 1.0 + float(target_enemy_count - current_enemies)
    elif current_enemies > target_enemy_count:
        multiplier = max(0.1, float(target_enemy_count) / current_enemies)
    spawn_timer.wait_time = spawn_interval / multiplier
    spawn_timer.start()

func _on_next_stage():
    current_loop += 1
    target_enemy_count = base_target_enemy_count + current_loop - 1
    spawn_timer.start()
    print("Stage %d started! Target enemies: %d" % [current_loop, target_enemy_count])
