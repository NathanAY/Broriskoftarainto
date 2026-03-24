extends GutTest

func test_enemy_health():
	var test_scene = load("res://test/TestScene.tscn").instantiate()
	get_tree().root.add_child(test_scene)
	
	var enemy = test_scene.get_node("Enemy")
	var health = enemy.get_node("Health")
	assert_true(health.current_health == 40, "Enemy health should be greater 40")

	await wait_seconds(3)
	assert_eq(health.current_health, 10)
	
	await wait_seconds(1.5)
	assert_null(enemy)

	test_scene.queue_free()
