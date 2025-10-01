extends Node
class_name Spawner

@export var spawn_interval = 3          # base interval in seconds
@export var base_target_enemy_count = 5 # initial target enemies per stage
@export var stage_duration = 5         # seconds per stage
@export var health_growth_per_stage: float = 20
@export var damage_growth_per_stage: float = 5
@export var character: Character

var enemy_scene = preload("res://Systems/Enemy.tscn")
var spawn_timer: Timer = null
var modifiers: Array = []
var enemiesNode: Node = null

@export var stage_time_elapsed: float = 0.0
@export var current_stage: int = 1
var target_enemy_count: int

var stage_active: bool = true

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
    target_enemy_count = base_target_enemy_count

func _process(delta: float) -> void:
    if not stage_active:
        return
    
    stage_time_elapsed += delta
    
    # End stage if time expired and all enemies dead
    if stage_time_elapsed >= stage_duration:
        if enemiesNode.get_child_count() == 0:
            _end_stage()

func _on_spawn_timer_timeout():
    if stage_time_elapsed < stage_duration:
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
    var extra_health = health_growth_per_stage * (current_stage - 1)
    var extra_damage = damage_growth_per_stage * (current_stage - 1)

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

func _end_stage():
    stage_active = false
    # Show stage end menu
    var menu: ShopMenu = get_tree().current_scene.get_node_or_null("UI/ShopMenu")
    if menu:
        menu.show_menu()
        menu.next_stage_pressed.connect(_on_next_stage_confirmed, CONNECT_ONE_SHOT)
        _clean_game_area()

func _clean_game_area():
    # cleanup stage-specific nodes (death marks, etc.)
    var death_marks_parent = get_tree().current_scene.get_node_or_null("Nodes/death_marks")
    for child in death_marks_parent.get_children():
        child.queue_free()
    var pickups = get_tree().current_scene.get_node_or_null("Nodes/pickups")
    for child in pickups.get_children():
        child.queue_free()
    var altars = get_tree().current_scene.get_node_or_null("Nodes/altars")
    for child in altars.get_children():
        child.queue_free()
    
func _on_next_stage_confirmed():
    current_stage += 1
    target_enemy_count = base_target_enemy_count + current_stage - 1
    stage_time_elapsed = 0.0
    stage_active = true
    spawn_timer.start()
    print("Stage %d started! Target enemies: %d" % [current_stage, target_enemy_count])
