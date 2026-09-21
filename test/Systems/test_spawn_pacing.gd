class_name SpawnPacingTest
extends GdUnitTestSuite


func _build_spawner() -> Dictionary:
	var root: Node = auto_free(Node.new())
	root.name = "TestRoot"
	add_child(root)
	var nodes := Node.new()
	nodes.name = "Nodes"
	root.add_child(nodes)
	var enemies := Node.new()
	enemies.name = "Enemies"
	nodes.add_child(enemies)
	var stage := Node.new()
	stage.name = "StageManager"
	root.add_child(stage)
	var character: CharacterBody2D = auto_free(load("res://src/Systems/Character.tscn").instantiate())
	root.add_child(character)
	character.global_position = Vector2(10000, 0)
	var spawner: EnemySpawner = auto_free(load("res://src/Systems/EnemySpawner.tscn").instantiate())
	spawner.set("character", character)
	stage.add_child(spawner)
	return {"root": root, "enemies": enemies, "spawner": spawner}


func _fill_enemies(enemies: Node, count: int) -> void:
	for i in range(count):
		enemies.add_child(Node.new())


func test_base_interval_is_1s() -> void:
	var ctx: Dictionary = _build_spawner()
	var spawner: EnemySpawner = ctx["spawner"]
	assert_int(spawner.spawn_interval).is_equal(1)


func test_empty_refill_loop_scaled() -> void:
	var ctx: Dictionary = _build_spawner()
	var spawner: EnemySpawner = ctx["spawner"]
	spawner.current_loop = 1
	assert_float(spawner.get_empty_refill_delay()).is_equal_approx(1.0, 0.001)
	spawner.current_loop = 2
	assert_float(spawner.get_empty_refill_delay()).is_equal_approx(0.85, 0.001)
	spawner.current_loop = 3
	assert_float(spawner.get_empty_refill_delay()).is_equal_approx(0.7, 0.001)
	spawner.current_loop = 99
	assert_float(spawner.get_empty_refill_delay()).is_equal_approx(0.3, 0.001)


func test_adjust_rate_never_exceeds_max_wait() -> void:
	var ctx: Dictionary = _build_spawner()
	var spawner: EnemySpawner = ctx["spawner"]
	var enemies: Node = ctx["enemies"]
	spawner.use_group_spawning = false
	# Heavy overpopulation: old code gave 3/0.1 = 30s. Must clamp to 4s.
	_fill_enemies(enemies, 50)
	spawner._adjust_spawn_rate()
	assert_bool(spawner.spawn_timer.wait_time <= 4.001).is_true()
	assert_bool(spawner.spawn_timer.wait_time >= 0.399).is_true()


func test_adjust_rate_speeds_up_when_empty() -> void:
	var ctx: Dictionary = _build_spawner()
	var spawner: EnemySpawner = ctx["spawner"]
	spawner.current_loop = 1
	spawner.use_group_spawning = false
	spawner._adjust_spawn_rate()
	assert_float(spawner.spawn_timer.wait_time).is_equal_approx(1.0, 0.001)


func test_over_alive_cap_skips_spawn() -> void:
	var ctx: Dictionary = _build_spawner()
	var spawner: EnemySpawner = ctx["spawner"]
	var enemies: Node = ctx["enemies"]
	spawner.use_group_spawning = false
	spawner.spawn_active = true
	_fill_enemies(enemies, 100)
	var before: int = enemies.get_child_count()
	spawner._on_spawn_timer_timeout()
	assert_int(enemies.get_child_count()).is_equal(before)
	assert_float(spawner.spawn_timer.wait_time).is_equal_approx(4.0, 0.001)


func test_start_wave_restarts_stopped_timer() -> void:
	var ctx: Dictionary = _build_spawner()
	var spawner: EnemySpawner = ctx["spawner"]
	spawner.spawn_active = false
	spawner.spawn_timer.stop()
	spawner.start_wave()
	assert_bool(spawner.spawn_active).is_true()
	assert_bool(spawner.spawn_timer.is_stopped()).is_false()
	assert_float(spawner.spawn_timer.wait_time).is_equal_approx(1.0, 0.001)


func test_watchdog_shortens_long_wait_when_empty() -> void:
	var ctx: Dictionary = _build_spawner()
	var spawner: EnemySpawner = ctx["spawner"]
	var enemies: Node = ctx["enemies"]
	spawner.current_loop = 1
	spawner.spawn_active = true
	spawner.spawn_timer.wait_time = 4.0
	spawner.spawn_timer.start()
	# Arena empty + 4s pending -> watchdog must shorten to ~1s refill.
	spawner._process(0.016)
	assert_float(spawner.spawn_timer.wait_time).is_equal_approx(1.0, 0.05)
