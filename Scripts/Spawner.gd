extends Node

@export var spawn_interval = 2.0
@export var health_growth_per_minute: float = 20.0
@export var damage_growth_per_minute: float = 5.0

var enemy_scene = preload("res://Scenes/Enemy.tscn")
var screen_size
var spawn_timer
var modifiers: Array = []

var elapsed_time: float = 0.0  # seconds since game start

func _ready():
    screen_size = get_viewport().get_visible_rect().size
    spawn_timer = Timer.new()
    add_child(spawn_timer)
    spawn_timer.wait_time = spawn_interval
    spawn_timer.one_shot = false
    spawn_timer.timeout.connect(_on_spawn_timer_timeout)
    spawn_timer.start()
    for c in get_children():
        if c.has_method("attach_to_enemy"):
            modifiers.append(c)
    print("Spawner ready! Screen size: ", screen_size)

func _process(delta: float) -> void:
    elapsed_time += delta

func _on_spawn_timer_timeout():
    spawn_enemy()

func spawn_enemy():
    var tower = get_parent().get_node_or_null("Tower")
    if not tower:
        return
    var enemy = enemy_scene.instantiate()
    var tower_position: Vector2 = tower.global_position
    # Pick a random angle in radians
    var angle = randf_range(0, TAU)
    var radius = 500.0
    # Calculate spawn position in a circle around tower
    var spawn_position = tower_position + Vector2(cos(angle), sin(angle)) * radius
    enemy.global_position = spawn_position

    # ✅ Apply global modifiers (from child nodes)
    for mod in modifiers:
        mod.attach_to_enemy(enemy)

    # ✅ Apply scaling
    _apply_scaling(enemy)

    add_child(enemy)
    enemy.set_target_position(tower_position)

func _apply_scaling(enemy: Node) -> void:
    var stats = enemy.get_node_or_null("Stats")
    if not stats:
        return

    var minutes = elapsed_time / 60.0
    var extra_health = health_growth_per_minute * minutes
    var extra_damage = damage_growth_per_minute * minutes

    stats.set_base_stat("health", stats.stats["health"] + extra_health)
    stats.set_base_stat("damage", stats.stats["damage"] + extra_damage)
