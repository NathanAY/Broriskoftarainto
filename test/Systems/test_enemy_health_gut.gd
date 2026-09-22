extends GutTest

func test_enemy_health():
    Engine.time_scale = 5
    var test_scene = load("res://test/TestScene.tscn").instantiate()
    get_tree().root.add_child(test_scene)
    get_tree().current_scene = test_scene
    
    var enemy = test_scene.get_node("Enemy")
    var health: Health = enemy.get_node("Health")
    assert_eq(health.current_health, 40.0, "Enemy health should be 40")

    await wait_seconds(int(3.5))
    assert_eq(health.current_health, 20.0)
    
    await wait_seconds(2)
    assert_false(is_instance_valid(enemy), "Enemy should be freed/invalid")

    test_scene.queue_free()
    
func test_enemy_health_with_much_attack_speed():
    Engine.time_scale = 5
    var test_scene = load("res://test/TestScene.tscn").instantiate()
    get_tree().root.add_child(test_scene)
    get_tree().current_scene = test_scene
    
    var character: Character = test_scene.get_node("Character")
    var c_stats: Stats = character.get_node_or_null("Stats")
    var _c_health: Health = character.get_node("Health")
    c_stats.set_base_stat("attack_speed", 20)

    var enemy: Enemy = test_scene.get_node("Enemy")
    var stats: Stats = enemy.get_node_or_null("Stats")
    var health: Health = enemy.get_node("Health")
    
    stats.set_base_stat("health", stats.stats["health"] + 1000)
    health.heal(1000)

    await wait_seconds(11)
    assert_null(enemy)

    test_scene.queue_free()
