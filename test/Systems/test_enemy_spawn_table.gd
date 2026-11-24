# The spawner used to spawn one hardcoded scene - `src/Systems/enemies/Enemy.tscn` -
# for every wave of every run. The spawn table replaces that with a list of
# enemy types, each with a weight and the stage it unlocks on, so a roster can
# be mixed in from the inspector.
class_name EnemySpawnTableTest
extends GdUnitTestSuite

const ENEMY_SCENE := "res://src/Systems/enemies/Enemy.tscn"
const BOSS_SCENE := "res://src/Systems/enemies/EnemyBoss.tscn"


## Weights live in `game_config.json` (`enemy_rarity`), not on the row, so a test
## that needs a particular weight sets it there with `_set_weight`.
func _entry(scene_path: String, min_stage: int = 1) -> EnemySpawnEntry:
    var entry := EnemySpawnEntry.new()
    entry.scene = load(scene_path)
    entry.min_stage = min_stage
    return entry


var _saved_rarity: Dictionary = {}


## Overrides one scene's `weight` in the live config block; `after_test` restores it.
func _set_weight(scene_path: String, weight: float) -> void:
    var block := GameConfig.section("enemy_rarity")
    var key := scene_path.get_file().get_basename()
    if not _saved_rarity.has(key):
        _saved_rarity[key] = block.get(key, null)
    block[key] = {"weight": weight}


func after_test() -> void:
    var block := GameConfig.section("enemy_rarity")
    for key in _saved_rarity:
        if _saved_rarity[key] == null:
            block.erase(key)
        else:
            block[key] = _saved_rarity[key]
    _saved_rarity.clear()

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
    var phase := Node.new()
    phase.name = "StageManager"
    root.add_child(phase)
    var character: Character = auto_free(load("res://src/Systems/Character.tscn").instantiate())
    root.add_child(character)
    var spawner: EnemySpawner = auto_free(load("res://src/Systems/EnemySpawner.tscn").instantiate())
    spawner.set("character", character)
    spawner.spawn_telegraph_time = 0.0 # these tests read the enemy straight after the call
    phase.add_child(spawner)
    return {"root": root, "enemies": enemies, "character": character, "spawner": spawner}


func test_empty_table_falls_back_to_the_fallback_scene() -> void:
    var spawner: EnemySpawner = _build_tree()["spawner"]
    assert_that(spawner.pick_enemy_scene()).is_equal(spawner.fallback_enemy_scene)


func test_a_row_locked_behind_a_later_stage_is_not_picked() -> void:
    var spawner: EnemySpawner = _build_tree()["spawner"]
    spawner.spawn_table = [_entry(BOSS_SCENE, 2)]

    spawner.current_stage = 1
    assert_that(spawner.pick_enemy_scene()).is_equal(spawner.fallback_enemy_scene)

    spawner.current_stage = 2
    assert_that(spawner.pick_enemy_scene()).is_equal(load(BOSS_SCENE))


func test_a_row_with_no_weight_never_comes_up() -> void:
    var spawner: EnemySpawner = _build_tree()["spawner"]
    _set_weight(ENEMY_SCENE, 0.0)
    _set_weight(BOSS_SCENE, 1.0)
    spawner.spawn_table = [_entry(ENEMY_SCENE), _entry(BOSS_SCENE)]

    for _i in range(20):
        assert_that(spawner.pick_enemy_scene()).is_equal(load(BOSS_SCENE))


func test_a_heavier_row_comes_up_more_often() -> void:
    var spawner: EnemySpawner = _build_tree()["spawner"]
    _set_weight(ENEMY_SCENE, 1.0)
    _set_weight(BOSS_SCENE, 9.0)
    spawner.spawn_table = [_entry(ENEMY_SCENE), _entry(BOSS_SCENE)]

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


func test_an_elite_row_scales_the_enemy_from_its_unlock_stage() -> void:
    var ctx := _build_tree()
    var spawner: EnemySpawner = ctx["spawner"]
    var enemies: Node = ctx["enemies"]
    spawner.use_group_spawning = false
    # Isolate the elite multiplier: the stage scaling would otherwise add health
    # on its own and hide which mechanism did it.
    spawner.health_growth_per_stage = 0.0
    spawner.damage_growth_per_stage = 0.0
    var entry := _entry(ENEMY_SCENE)
    entry.elite_min_stage = 3
    spawner.spawn_table = [entry]

    spawner.current_stage = 1
    spawner.spawn_enemy()
    var normal := enemies.get_child(0) as Enemy
    var normal_health := normal.stats.get_stat("health")

    spawner.current_stage = 3
    spawner.spawn_enemy()
    var elite := enemies.get_child(1) as Enemy

    assert_float(elite.stats.get_stat("health")).override_failure_message(
        "an elite row spawned a normal-health enemy at its unlock stage"
    ).is_greater(normal_health)
    var visual := elite.get_node("Node2D") as CanvasItem
    assert_bool(visual.modulate.is_equal_approx(Color.WHITE)).override_failure_message(
        "an elite was not tinted, so it reads as an ordinary enemy"
    ).is_false()


func test_a_row_below_its_elite_stage_is_not_elite() -> void:
    var ctx := _build_tree()
    var spawner: EnemySpawner = ctx["spawner"]
    var enemies: Node = ctx["enemies"]
    spawner.use_group_spawning = false
    spawner.health_growth_per_stage = 0.0
    var entry := _entry(ENEMY_SCENE)
    entry.elite_min_stage = 3
    spawner.spawn_table = [entry]

    spawner.current_stage = 1
    spawner.spawn_enemy()

    var normal := enemies.get_child(0) as Enemy
    var visual := normal.get_node("Node2D") as CanvasItem
    assert_bool(visual.modulate.is_equal_approx(Color.WHITE)).override_failure_message(
        "an enemy was elite before its row's unlock stage"
    ).is_true()


const BULWARK_SCENE := "res://src/Systems/enemies/EnemyBulwark.tscn"
const LANCER_SCENE := "res://src/Systems/enemies/EnemyLancer.tscn"


## Rarity numbers are read from `game_config.json`, so the tests derive their
## expectation from the same block instead of pinning a literal.
func _rarity(scene_path: String) -> Dictionary:
    return GameConfig.section("enemy_rarity").get(scene_path.get_file().get_basename(), {})


func test_a_row_weight_comes_from_the_config() -> void:
    var spawner: EnemySpawner = _build_tree()["spawner"]

    assert_float(spawner._entry_weight(_entry(BULWARK_SCENE))).is_equal_approx(
        float(_rarity(BULWARK_SCENE)["weight"]), 0.0001)


func test_a_scene_missing_from_the_config_weighs_one() -> void:
    var spawner: EnemySpawner = _build_tree()["spawner"]

    assert_float(spawner._entry_weight(_entry(BOSS_SCENE))).is_equal_approx(1.0, 0.0001)


func test_a_special_enemy_health_comes_from_the_config() -> void:
    var ctx := _build_tree()
    var spawner: EnemySpawner = ctx["spawner"]
    var enemies: Node = ctx["enemies"]
    spawner.use_group_spawning = false
    spawner.health_growth_per_stage = 0.0
    spawner.spawn_table = [_entry(LANCER_SCENE)]

    spawner.spawn_enemy()

    var spawned := enemies.get_child(0) as Enemy
    assert_float(spawned.stats.get_stat("health")).is_equal_approx(
        float(_rarity(LANCER_SCENE)["base_health"]), 0.0001)
