# GdUnit generated TestSuite
class_name DebugScenariosTest
extends GdUnitTestSuite

## Covers what each `test/scenarios/scenario_*.tscn` does to a run it starts: the
## weapons and items it equips, and the stage/loop it jumps to.
##
## Each test runs the real scene, because the two things worth pinning - that the
## loadout survives `Character._ready()` and that the stage jump lands after
## `StageManager._ready()` - only exist once the whole `Game.tscn` is up.

const LOADED_BUILD := "res://test/scenarios/scenario_loaded_build.tscn"
const FIRST_BOSS := "res://test/scenarios/scenario_first_boss.tscn"
const LOOP_THREE := "res://test/scenarios/scenario_loop_three.tscn"

## `ScenarioSetup` waits one frame before it equips anything, so the assertions
## below have to sit past that frame.
const SETTLE_FRAMES := 3

var saved_character: Variant
var saved_weapons: Array[String]
var saved_items: Array[String]
var saved_scene: Node
var running_scenario: Node = null


func before_test() -> void:
    # The scenarios write `GlobalGameState`, which outlives the test.
    saved_character = GlobalGameState.starting_character
    saved_weapons = GlobalGameState.starting_weapons.duplicate()
    saved_items = GlobalGameState.starting_items.duplicate()
    saved_scene = get_tree().current_scene


func after_test() -> void:
    GlobalGameState.starting_character = saved_character
    GlobalGameState.starting_weapons = saved_weapons
    GlobalGameState.starting_items = saved_items
    # Restored before the free: a `Game.tscn` left as `current_scene` would give
    # `StageManager` a node that is on its way out, and the enemies it spawns
    # keep hitting the character for as long as the test takes.
    get_tree().current_scene = saved_scene
    if is_instance_valid(running_scenario):
        running_scenario.queue_free()
        running_scenario = null
    collect_orphan_node_details()


func test_loaded_build_equips_four_weapons_and_stacked_items() -> void:
    var scenario := await _run_scenario(LOADED_BUILD)
    var character: Character = scenario.get_node("Character")

    assert_int(character.weapon_holder.weapons.size()).is_equal(4)
    # Two named items plus the three stacked ones.
    assert_int(character.item_holder.items.size()).is_equal(5)
    # Every stacked item is multi-modifier, which is the point of this scenario.
    for item in character.item_holder.items:
        if item.name.begins_with("Veteran") or item.name.begins_with("Chain Reactor") \
                or item.name.begins_with("Survivor"):
            assert_int(item.modifiers.size()).override_failure_message(
                "%s carries %d modifiers" % [item.name, item.modifiers.size()]
            ).is_greater_equal(3)


func test_loaded_build_stays_on_the_first_enemy_stage() -> void:
    var scenario := await _run_scenario(LOADED_BUILD)
    var stage_manager: StageManager = scenario.get_node("StageManager")

    assert_int(stage_manager.current_stage).is_equal(1)
    assert_int(stage_manager.current_loop).is_equal(1)
    assert_int(stage_manager.enemy_spawner.current_loop).is_equal(1)


func test_first_boss_skips_the_enemy_stage() -> void:
    var scenario := await _run_scenario(FIRST_BOSS)
    var stage_manager: StageManager = scenario.get_node("StageManager")

    assert_int(stage_manager.current_stage).is_equal(2)
    assert_bool(stage_manager.boss_spawner.spawn_active).is_true()
    # The enemy stage never ran, so nothing should be queued up behind it.
    assert_bool(stage_manager.enemy_spawner.spawn_active).is_false()


func test_loop_three_scales_both_spawners() -> void:
    var scenario := await _run_scenario(LOOP_THREE)
    var stage_manager: StageManager = scenario.get_node("StageManager")

    assert_int(stage_manager.current_stage).is_equal(1)
    # All three counters have to agree: `start_new_loop()` normally keeps them in
    # step, and a scenario that set only one would spawn loop-2 enemies in loop 3.
    assert_int(stage_manager.current_loop).is_equal(3)
    assert_int(stage_manager.enemy_spawner.current_loop).is_equal(3)
    assert_int(stage_manager.boss_spawner.current_loop).is_equal(3)
    # The wave is sized from `current_loop`, so a stale loop-1 wave is the failure
    # this catches.
    assert_int(stage_manager.enemy_spawner.target_enemy_count).is_equal(
        stage_manager.enemy_spawner.base_target_enemy_count + 2
    )


func test_scenario_uses_the_requested_character() -> void:
    var scenario := await _run_scenario(LOADED_BUILD)
    var setup: DebugScenarioSetup = scenario.get_node("ScenarioSetup")

    assert_str(GlobalGameState.starting_character).is_equal(setup.character_path)
    assert_object(GlobalGameState.current_character).is_same(
        _current_character(scenario)
    )


## Instantiates a scenario scene and lets `ScenarioSetup` finish applying it.
## The scene is published as `current_scene` because that is how the real game
## runs it: `StageManager` reaches the arena through
## `get_tree().current_scene`, so anything that happens in a scenario - a death
## being the obvious one - would break under a test-only current scene.
func _run_scenario(path: String) -> Node:
    running_scenario = load(path).instantiate()
    # Under the root, not under this suite: `SceneTree.set_current_scene()` errors
    # on a node whose parent is not the root, and the scenario is the current
    # scene for as long as it runs.
    get_tree().root.add_child(running_scenario)
    get_tree().current_scene = running_scenario
    for _frame in SETTLE_FRAMES:
        await get_tree().process_frame
    return running_scenario


## The scenario nodes are children of this suite and are freed with it, but a
## spawned enemy may outlive one test, so the character is looked up in the tree
## rather than off the node.
func _current_character(scenario: Node) -> Character:
    var found := get_tree().get_nodes_in_group("character")
    for node in found:
        if scenario.is_ancestor_of(node):
            return node as Character
    return null
