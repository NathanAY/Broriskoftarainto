#tower.gd
extends Node2D

@onready var event_manager = $EventManager
@onready var item_holder = $ItemHolder
@onready var stats = $Stats


var projectile_scene = preload("res://Scenes/Projectile.tscn")
var current_target = null
var fire_timer = 0.0
var timer = Timer.new()
var attack_range = 500

var modifiers: Array = []

func _ready():
    # Create a timer for shooting
    add_child(timer)
    _update_fire_timer()
    timer.timeout.connect(_on_shoot_timer_timeout)
    timer.start()
    for c in get_children():
        if c.has_method("attachEventManager"):
            c.attachEventManager(event_manager)  # attach SpreadModifier to this tower
            modifiers.append(c)
    print("Tower: found modifiers:", modifiers)
    event_manager.subscribe("on_stat_changes", Callable(self, "_on_stat_changed"))

func _on_stat_changed(event) -> void:
    _update_fire_timer()

func _update_fire_timer():
    var attack_speed = stats.get_stat("attack_speed")
    timer.wait_time = 1.0 / attack_speed

func _draw():
    # Draw a circle showing the attack range (for debugging)
    draw_circle(Vector2.ZERO, stats.get_stat("attack_range"), Color(1, 0, 0, 0.02))
    pass

func _on_area_2d_area_entered(area: Area2D) -> void:
    if area.get_parent().is_in_group("enemies"):
        area.get_parent().queue_free()
        print("Enemy destroyed!")
        
func _on_shoot_timer_timeout():
    try_shoot()

func try_shoot():
    # Find all enemies in range
    var enemies_in_range = []
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if global_position.distance_to(enemy.global_position) <= stats.get_stat("attack_range"):
            enemies_in_range.append(enemy)

    # If there are enemies in range, target the closest one
    if enemies_in_range.size() > 0:
        enemies_in_range.sort_custom(_sort_by_distance)
        current_target = enemies_in_range[0]
        shoot_at(current_target)

func _sort_by_distance(a, b):
    return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)

func shoot_at(target):
    var projectile = projectile_scene.instantiate()
    projectile.set_event_manager(event_manager)
    # Position projectile at tower center
    projectile.global_position = global_position
    # Calculate direction to target
    var direction = (target.global_position - global_position).normalized()
    projectile.set_direction(direction)
    projectile.damage = stats.get_stat("damage")
    # Connect before init
    #projectile.connect("projectile_hit", Callable(self, "_on_projectile_hit"))
    get_parent().add_child(projectile)  # Add to main scene, not tower
    #print("Tower shooting at enemy!")
    # attach modifiers, but skip if the projectile was marked as spawned_by_chain
    if projectile.get_meta("spawned_by_chain", false):
        print("Tower: projectile spawned_by_chain - skipping modifiers attachment")
    else:
        for mod in modifiers:
            if mod.has_method("attach_to_projectile"):
                print("Tower: attaching modifier", mod, "to projectile", projectile)
                mod.attach_to_projectile(projectile)
    # 🔹 Emit attack signal
    event_manager.emit_event("on_attack", [{"projectile": projectile}])
