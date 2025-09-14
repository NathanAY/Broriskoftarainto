extends Node

@export var spawn_interval = 200.0
var enemy_scene = preload("res://Scenes/Enemy.tscn")
var screen_size
var spawn_timer
var modifiers: Array = []

func _ready():
    screen_size = get_viewport().get_visible_rect().size
    # Create and configure the timer
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

func _on_spawn_timer_timeout():
    spawn_enemy()

func spawn_enemy():
    var tower = get_parent().get_node_or_null("Tower")
    if not tower:
        return
    var enemy = enemy_scene.instantiate()
    var tower_position: Vector2 = tower.global_position
    # Pick a random angle in radians
    var angle = randf_range(0, TAU)  # TAU = 2 * PI
    var radius = 500.0  # distance from tower/player
    # Calculate spawn position in a circle around tower
    var spawn_position = tower_position + Vector2(cos(angle), sin(angle)) * radius

    enemy.global_position = spawn_position
    for mod in modifiers:
        mod.attach_to_enemy(enemy)
    add_child(enemy)
    enemy.set_target_position(tower_position)
