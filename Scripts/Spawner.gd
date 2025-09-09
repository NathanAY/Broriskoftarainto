extends Node2D

@export var spawn_interval = 1.0
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
    var enemy = enemy_scene.instantiate()
    
    # Randomly select a side to spawn from
    var side = randi() % 4  # 0: top, 1: right, 2: bottom, 3: left
    var spawn_position = Vector2()
    
    match side:
        0:  # Top
            spawn_position = Vector2(randf_range(50, screen_size.x - 50), -50)
        1:  # Right
            spawn_position = Vector2(screen_size.x + 50, randf_range(50, screen_size.y - 50))
        2:  # Bottom
            spawn_position = Vector2(randf_range(50, screen_size.x - 50), screen_size.y + 50)
        3:  # Left
            spawn_position = Vector2(-50, randf_range(50, screen_size.y - 50))
    
    enemy.position = spawn_position
    enemy.set_target_position(Vector2(screen_size.x / 2, screen_size.y / 2))
    #enemy.target_position = Vector2(screen_size.x / 2, screen_size.y / 2)  # Center of screen
    for mod in modifiers:
        mod.attach_to_enemy(enemy)
    add_child(enemy)
    #print("Spawned enemy at position: ", spawn_position)
