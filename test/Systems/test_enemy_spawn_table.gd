# The spawner used to spawn one hardcoded scene - `src/Systems/Enemy.tscn` -
# for every wave of every run. The spawn table replaces that with a list of
# enemy types, each with a weight and the loop it unlocks on, so a roster can
# be mixed in from the inspector.
class_name EnemySpawnTableTest
extends GdUnitTestSuite

const ENEMY_SCENE := "res://src/Systems/Enemy.tscn"
const BOSS_SCENE := "res://src/Systems/EnemyBoss.tscn"


func _entry(scene_path: String, weight: float = 1.0, min_loop: int = 1) -> EnemySpawnEntry:
    var entry := EnemySpawnEntry.new()
    entry.scene = load(scene_path)
    entry.weight = weight
    entry.min_loop = min_loop
    return entry


## The tree every enemy-spawning test wants: TestRoot/Nodes/Enemies,
## TestRoot/StageManager/<spawner>, TestRoot/Character. The spawner reaches its
## enemy container with a relative `get_node("../../Nodes/Enemies")`, so its
## place in that tree is part of its contract.
func _build_tree() -> Dictionary:
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
    var character: Character = auto_free(load("res://src/Systems/Character.tscn").instantiate())
    root.add_child(character)
    var spawner: EnemySpawner = auto_free(load("res://src/Systems/EnemySpawner.tscn").instantiate())
    spawner.set("character", character)
    stage.add_child(spawner)
    return {"root": root, "enemies": enemies, "character": character, "spawner": spawner}


func test_empty_table_falls_back_to_the_fallback_scene() -> void:
    var spawner: EnemySpawner = _build_tree()["spawner"]
    assert_that(spawner.pick_enemy_scene()).is_equal(spawner.fallback_enemy_scene)


func test_a_row_locked_behind_a_later_loop_is_not_picked() -> void:
    var spawner: EnemySpawner = _build_tree()["spawner"]
    spawner.spawn_table = [_entry(BOSS_SCENE, 1.0, 2)]

    spawner.current_loop = 1
    assert_that(spawner.pick_enemy_scene()).is_equal(spawner.fallback_enemy_scene)

    spawner.current_loop = 2
    assert_that(spawner.pick_enemy_scene()).is_equal(load(BOSS_SCENE))


func test_a_row_with_no_weight_never_comes_up() -> void:
    var spawner: EnemySpawner = _build_tree()["spawner"]
    spawner.spawn_table = [_entry(ENEMY_SCENE, 0.0), _entry(BOSS_SCENE, 1.0)]

    for _i in range(20):
        assert_that(spawner.pick_enemy_scene()).is_equal(load(BOSS_SCENE))


func test_a_heavier_row_comes_up_more_often() -> void:
    var spawner: EnemySpawner = _build_tree()["spawner"]
    spawner.spawn_table = [_entry(ENEMY_SCENE, 1.0), _entry(BOSS_SCENE, 9.0)]

    var light := 0
    var heavy := 0
    for _i in range(200):
        if spawner.pick_enemy_scene() == load(BOSS_SCENE):
            heavy += 1
        else:
            light += 1

    assert_int(heavy).is_greater(light)
    assert_int(light).is_greater(0)


func test_the_spawner_spawns_the_scene_the_table_picks() -> void:
    var ctx := _build_tree()
    var spawner: EnemySpawner = ctx["spawner"]
    var enemies: Node = ctx["enemies"]
    spawner.use_group_spawning = false
    spawner.spawn_table = [_entry(BOSS_SCENE)]

    spawner.spawn_enemy()

    assert_int(enemies.get_child_count()).is_equal(1)
    var spawned := enemies.get_child(0) as Enemy
    assert_object(spawned).is_not_null()
    assert_that(spawned.scene_file_path).is_equal(BOSS_SCENE)


func test_a_pack_row_spawns_its_whole_pack() -> void:
    var ctx := _build_tree()
    var spawner: EnemySpawner = ctx["spawner"]
    var enemies: Node = ctx["enemies"]
    spawner.use_group_spawning = false
    var entry := _entry(ENEMY_SCENE)
    entry.pack_size = 8
    spawner.spawn_table = [entry]

    spawner.spawn_enemy()

    assert_int(enemies.get_child_count()).override_failure_message(
        "a pack row spawned fewer bodies than its pack size"
    ).is_equal(entry.pack_size)


func test_an_elite_row_scales_the_enemy_from_its_unlock_loop() -> void:
    var ctx := _build_tree()
    var spawner: EnemySpawner = ctx["spawner"]
    var enemies: Node = ctx["enemies"]
    spawner.use_group_spawning = false
    # Isolate the elite multiplier: the loop scaling would otherwise add health
    # on its own and hide which mechanism did it.
    spawner.health_growth_per_loop = 0.0
    spawner.damage_growth_per_loop = 0.0
    var entry := _entry(ENEMY_SCENE)
    entry.elite_min_loop = 3
    spawner.spawn_table = [entry]

    spawner.current_loop = 1
    spawner.spawn_enemy()
    var normal := enemies.get_child(0) as Enemy
    var normal_health := normal.stats.get_stat("health")

    spawner.current_loop = 3
    spawner.spawn_enemy()
    var elite := enemies.get_child(1) as Enemy

    assert_float(elite.stats.get_stat("health")).override_failure_message(
        "an elite row spawned a normal-health enemy at its unlock loop"
    ).is_greater(normal_health)
    var visual := elite.get_node("Node2D") as CanvasItem
    assert_bool(visual.modulate.is_equal_approx(Color.WHITE)).override_failure_message(
        "an elite was not tinted, so it reads as an ordinary enemy"
    ).is_false()


func test_a_row_below_its_elite_loop_is_not_elite() -> void:
    var ctx := _build_tree()
    var spawner: EnemySpawner = ctx["spawner"]
    var enemies: Node = ctx["enemies"]
    spawner.use_group_spawning = false
    spawner.health_growth_per_loop = 0.0
    var entry := _entry(ENEMY_SCENE)
    entry.elite_min_loop = 3
    spawner.spawn_table = [entry]

    spawner.current_loop = 1
    spawner.spawn_enemy()

    var normal := enemies.get_child(0) as Enemy
    var visual := normal.get_node("Node2D") as CanvasItem
    assert_bool(visual.modulate.is_equal_approx(Color.WHITE)).override_failure_message(
        "an enemy was elite before its row's unlock loop"
    ).is_true()
