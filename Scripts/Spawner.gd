extends Node
class_name Spawner

@export var spawn_interval = 3        # base interval in seconds
@export var target_enemy_count = 4      # target number of enemies
@export var health_growth_per_minute: float = 20.0
@export var damage_growth_per_minute: float = 5.0

var enemy_scene = preload("res://Scenes/Enemy.tscn")
var spawn_timer: Timer = null
var modifiers: Array = []
var enemiesNode: Node = null

var elapsed_time: float = 0.0  # seconds since game start

func _ready():
    spawn_timer = Timer.new()
    spawn_timer.wait_time = spawn_interval
    spawn_timer.one_shot = false
    spawn_timer.timeout.connect(_on_spawn_timer_timeout)
    add_child(spawn_timer)
    spawn_timer.start()
    enemiesNode = get_node("Enemies")
    for c in get_children():
        if c.has_method("attach_to_enemy"):
            modifiers.append(c)

func _process(delta: float) -> void:
    elapsed_time += delta

func _on_spawn_timer_timeout():
    spawn_enemy()
    _adjust_spawn_rate()

func spawn_enemy():
    var character = get_parent().get_node_or_null("Character")
    if not character:
        return
    var enemy = enemy_scene.instantiate()
    var character_position: Vector2 = character.global_position
    # Pick a random angle in radians
    var angle = randf_range(0, TAU)
    var radius = 500.0
    # Calculate spawn position in a circle around character
    var spawn_position = character_position + Vector2(cos(angle), sin(angle)) * radius
    enemy.global_position = spawn_position

    # ✅ Apply global modifiers (from child nodes)
    for mod in modifiers:
        mod.attach_to_enemy(enemy)

    # ✅ Apply scaling
    _apply_scaling(enemy)

    enemiesNode.add_child(enemy)
    enemy.set_target_position(character)

func _apply_scaling(enemy: Node) -> void:
    var stats = enemy.get_node_or_null("Stats")
    if not stats:
        return

    var minutes = elapsed_time / 60.0
    var extra_health = health_growth_per_minute * minutes
    var extra_damage = damage_growth_per_minute * minutes

    stats.set_base_stat("health", stats.stats["health"] + extra_health)
    stats.set_base_stat("damage", stats.stats["damage"] + extra_damage)

func _adjust_spawn_rate():
    # Count current enemies
    var current_enemies = enemiesNode.get_children().size()
    # Calculate multiplier:
    # If current < target → spawn faster
    # If current > target → spawn slower
    var multiplier = 1.0
    if current_enemies < target_enemy_count:
        multiplier = 1.0 + float(target_enemy_count - current_enemies)  # e.g., 5x faster
    elif current_enemies > target_enemy_count:
        multiplier = max(0.1, float(target_enemy_count) / current_enemies) # slower but not zero
    # Update timer wait_time dynamically
    spawn_timer.wait_time = spawn_interval / multiplier
    spawn_timer.start()
