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
    var count_before: int = enemies.get_child_count()
    spawner._on_spawn_timer_timeout()
    assert_int(enemies.get_child_count()).is_equal(count_before)
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
    var _enemies: Node = ctx["enemies"]
    spawner.current_loop = 1
    spawner.spawn_active = true
    spawner.spawn_timer.wait_time = 4.0
    spawner.spawn_timer.start()
    # Arena empty + 4s pending -> watchdog must shorten to ~1s refill.
    spawner._process(0.016)
    assert_float(spawner.spawn_timer.wait_time).is_equal_approx(1.0, 0.05)


## A multiplier must scale the wave it is applied to, not just be remembered:
## `set_spawn_multiplier()` is called after `Game.tscn` has already booted and
## `start_wave()` has already sized the wave, so the target has to be recomputed.
func test_set_spawn_multiplier_resizes_the_live_wave() -> void:
    var ctx: Dictionary = _build_spawner()
    var spawner: EnemySpawner = ctx["spawner"]
    spawner.start_wave()
    assert_int(spawner.target_enemy_count).is_equal(spawner.base_target_enemy_count)

    spawner.set_spawn_multiplier(4.0)
    assert_int(spawner.target_enemy_count).is_equal(
        roundi(float(spawner.base_target_enemy_count + spawner.current_loop - 1) * 4.0)
    )

    # And back down again, without the first scaling having been baked in.
    spawner.set_spawn_multiplier(1.0)
    assert_int(spawner.target_enemy_count).is_equal(
        spawner.base_target_enemy_count + spawner.current_loop - 1
    )


func test_multiplier_scales_loop_scaling_too() -> void:
    var ctx: Dictionary = _build_spawner()
    var spawner: EnemySpawner = ctx["spawner"]
    spawner.current_loop = 3
    spawner.set_spawn_multiplier(2.0)
    assert_int(spawner.target_enemy_count).is_equal(
        (spawner.base_target_enemy_count + 2) * 2
    )
    # `start_wave()` re-sizes from `current_loop`, so it must not drop the
    # multiplier on the way - which is the order a scenario hits it in.
    spawner.start_wave()
    assert_int(spawner.target_enemy_count).is_equal(
        (spawner.base_target_enemy_count + 2) * 2
    )


## 0.1x must not round the wave to nothing: `StageManager` only ends a stage on
## an empty arena, so a stage that never fields a monster would never end.
func test_low_multiplier_still_fields_one_enemy() -> void:
    var ctx: Dictionary = _build_spawner()
    var spawner: EnemySpawner = ctx["spawner"]
    spawner.set_spawn_multiplier(0.1)
    assert_int(spawner.target_enemy_count).is_equal(1)
    assert_int(spawner.scaled_group_size()).is_equal(1)
    assert_int(spawner.scaled_groups_per_tick()[0]).is_equal(1)


func test_low_multiplier_still_spawns_with_an_empty_arena() -> void:
    var ctx: Dictionary = _build_spawner()
    var spawner: EnemySpawner = ctx["spawner"]
    spawner.set_spawn_multiplier(0.1)
    assert_int(spawner.spawn_budget()).is_greater_equal(1)


func test_high_multiplier_scales_population_and_batch() -> void:
    var ctx: Dictionary = _build_spawner()
    var spawner: EnemySpawner = ctx["spawner"]
    spawner.set_spawn_multiplier(20.0)
    assert_int(spawner.target_enemy_count).is_equal(
        spawner.base_target_enemy_count * 20
    )
    assert_int(spawner.scaled_group_size()).is_equal(spawner.group_size * 20)
    assert_int(spawner.scaled_groups_per_tick()[1]).is_equal(
        spawner.max_groups_per_spawn * 20
    )


## The alive-enemy ceiling has to follow the population, or the cap silently
## truncates a 20x wave back down to whatever `max_alive_enemies` says.
func test_high_multiplier_raises_the_alive_ceiling() -> void:
    var ctx: Dictionary = _build_spawner()
    var spawner: EnemySpawner = ctx["spawner"]
    assert_int(spawner.max_alive_for_multiplier()).is_equal(spawner.max_alive_enemies)

    spawner.set_spawn_multiplier(20.0)
    assert_int(spawner.max_alive_for_multiplier()).is_greater_equal(
        spawner.target_enemy_count
    )
    assert_int(spawner.max_alive_for_multiplier()).is_equal(
        spawner.max_alive_enemies * 20
    )


## One tick may overshoot the target by the batch an ordinary spawner would have
## added - that is the shipped behaviour at 1.0 - but not by its whole budget.
## At 20x the batch is thousands of enemies and the ceiling is only checked
## *before* a tick, so without the deficit cap a single tick dumps the arena.
func test_budget_never_overshoots_by_more_than_the_unscaled_batch() -> void:
    var ctx: Dictionary = _build_spawner()
    var spawner: EnemySpawner = ctx["spawner"]
    var enemies: Node = ctx["enemies"]
    spawner.set_spawn_multiplier(20.0)
    spawner.start_wave()
    var unscaled_batch: int = spawner.group_size * spawner.max_groups_per_spawn

    # Arena empty, so the deficit is at its largest.
    assert_int(spawner.spawn_budget()).is_equal(
        spawner.target_enemy_count + unscaled_batch
    )

    # Arena already at the target: only the ordinary overshoot is left.
    _fill_enemies(enemies, spawner.target_enemy_count)
    assert_int(spawner.spawn_budget()).is_equal(unscaled_batch)

    # Past the target the deficit is clamped, so a full arena never gets a fresh
    # full budget handed out on top of what is already alive.
    _fill_enemies(enemies, spawner.target_enemy_count + 10)
    assert_int(spawner.spawn_budget()).is_equal(unscaled_batch)


## At 1.0 the budget is exactly the shipped batch, or the whole scaling above is
## free to change how a normal run spawns.
func test_budget_at_1x_is_the_shipped_batch() -> void:
    var ctx: Dictionary = _build_spawner()
    var spawner: EnemySpawner = ctx["spawner"]
    var enemies: Node = ctx["enemies"]
    var shipped_batch: int = spawner.group_size * spawner.max_groups_per_spawn
    for alive in [0, 1, 5, 50]:
        for child in enemies.get_children():
            child.queue_free()
        _fill_enemies(enemies, alive)
        assert_int(spawner.spawn_budget()).override_failure_message(
            "budget at 1x with %d alive" % alive
        ).is_equal(shipped_batch)


func test_cadence_speeds_up_with_the_multiplier() -> void:
    var ctx: Dictionary = _build_spawner()
    var spawner: EnemySpawner = ctx["spawner"]
    assert_float(spawner.scaled_spawn_interval()).is_equal_approx(1.0, 0.001)

    spawner.set_spawn_multiplier(20.0)
    assert_float(spawner.scaled_spawn_interval()).is_equal_approx(0.05, 0.001)
    assert_float(spawner.scaled_min_spawn_wait()).is_equal_approx(0.02, 0.001)
    assert_float(spawner.scaled_max_spawn_wait()).is_equal_approx(0.2, 0.001)

    # The other end has to be *slower*, otherwise every value under 1x would
    # behave the same: one enemy per second is not 0.1x of anything.
    spawner.set_spawn_multiplier(0.1)
    assert_float(spawner.scaled_spawn_interval()).is_equal_approx(10.0, 0.001)
    assert_float(spawner.scaled_min_spawn_wait()).is_equal_approx(4.0, 0.001)
    assert_float(spawner.scaled_max_spawn_wait()).is_equal_approx(40.0, 0.001)


func test_multiplier_is_clamped_to_the_documented_range() -> void:
    var ctx: Dictionary = _build_spawner()
    var spawner: EnemySpawner = ctx["spawner"]
    spawner.set_spawn_multiplier(0.0)
    assert_float(spawner.spawn_multiplier).is_equal_approx(
        EnemySpawner.MIN_SPAWN_MULTIPLIER, 0.001
    )
    spawner.set_spawn_multiplier(1000.0)
    assert_float(spawner.spawn_multiplier).is_equal_approx(
        EnemySpawner.MAX_SPAWN_MULTIPLIER, 0.001
    )
