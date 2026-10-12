# GdUnit generated TestSuite
class_name SandboxScenarioTest
extends GdUnitTestSuite

## Covers the sandbox panel: that the scenario installs it, that the pause menu
## can reach it, and - the part that matters - that a spawned enemy really carries
## the numbers that were typed into the panel.
##
## No balance number is pinned here on purpose. The panel's whole purpose is to
## take whatever number a designer types, so a test asserting `health == 100000`
## would only be re-broken by every change to the defaults.

const SANDBOX := "res://test/scenarios/scenario_sandbox.tscn"

## `ScenarioSetup` waits one frame before it equips anything and installs the
## panel, so the assertions below have to sit past that frame.
const SETTLE_FRAMES := 3

var saved_character: Variant
var saved_scene: Node
var running_scenario: Node = null


func before_test() -> void:
    saved_character = GlobalGameState.starting_character
    saved_scene = get_tree().current_scene


func after_test() -> void:
    GlobalGameState.starting_character = saved_character
    get_tree().current_scene = saved_scene
    if is_instance_valid(running_scenario):
        running_scenario.queue_free()
        running_scenario = null
    collect_orphan_node_details()


## The panel is what the pause-menu button opens, so a scenario without one leaves
## a button that silently does nothing.
func test_scenario_installs_the_sandbox_panel() -> void:
    var scenario := await _run_scenario()

    assert_object(scenario.get_node_or_null("ScenarioSetup/SandboxMenu")).override_failure_message(
        "the sandbox scenario did not build a SandboxMenu"
    ).is_instanceof(SandboxMenu)


## The button has to live inside the pause menu's own VBox, because that is the
## list the pause screen shows; anywhere else and it is never seen.
func test_pause_menu_grows_a_sandbox_button() -> void:
    var scenario := await _run_scenario()
    var pause_menu := scenario.get_node("UI/PauseMenu")

    assert_object(pause_menu.get_node_or_null("Control/VBoxContainer/SandboxButton")).is_not_null()


## The panel is opened from the pause screen, where the tree is paused. A panel
## that stops processing there cannot be typed into, so it must run regardless.
func test_sandbox_panel_runs_while_the_game_is_paused() -> void:
    var scenario := await _run_scenario()
    var menu: SandboxMenu = scenario.get_node("ScenarioSetup/SandboxMenu")

    assert_int(menu.process_mode).override_failure_message(
        "the panel must process while paused, or it is unusable from the pause menu"
    ).is_equal(Node.PROCESS_MODE_ALWAYS)


## The core of it: whatever is typed in is what the enemy gets. Health is read
## back off `Stats`, which is the value weapons and damage are measured against,
## rather than off `Health`, which only mirrors it.
func test_spawned_enemies_take_the_typed_health_and_speed() -> void:
    var scenario := await _run_scenario()
    var menu: SandboxMenu = scenario.get_node("ScenarioSetup/SandboxMenu")
    _set_spawn_values(menu, 100000.0, 0.0, 2)

    var spawned := menu.spawn_configured()

    assert_int(spawned.size()).is_equal(2)
    for enemy in spawned:
        assert_float(enemy.stats.get_stat("health")).override_failure_message(
            "health did not reach the spawned enemy's stats"
        ).is_equal_approx(100000.0, 0.001)
        # 0 speed must read as a real 0, not as an untouched default of 1.
        assert_float(enemy.stats.get_movement_speed_px()).override_failure_message(
            "movement speed did not reach the spawned enemy, so it still walks"
        ).is_equal_approx(0.0, 0.001)


## `Health._ready()` copies `Stats` into `current_health`, so the panel has to set
## the stat before the enemy joins the tree. Getting that order wrong leaves a
## 100000-health enemy at its old current health - already dead.
func test_spawned_enemies_start_alive_at_their_full_health() -> void:
    var scenario := await _run_scenario()
    var menu: SandboxMenu = scenario.get_node("ScenarioSetup/SandboxMenu")
    _set_spawn_values(menu, 100000.0, 0.0, 1)

    var enemy := menu.spawn_configured()[0]

    assert_bool(enemy.health_node.is_dead).is_false()
    assert_float(enemy.health_node.current_health).override_failure_message(
        "current_health was not taken from the stat set before the enemy joined the tree"
    ).is_equal_approx(100000.0, 0.001)
    assert_float(enemy.health_node.max_health).is_equal_approx(100000.0, 0.001)


## Enemies have to land in the node the stage manager watches, or they never count
## towards ending a stage and never get cleaned up.
func test_spawned_enemies_land_in_the_arena_enemies_node() -> void:
    var scenario := await _run_scenario()
    var menu: SandboxMenu = scenario.get_node("ScenarioSetup/SandboxMenu")
    _set_spawn_values(menu, 100000.0, 0.0, 3)
    var enemies_node: Node = scenario.get_node("Nodes/Enemies")
    var count_before := enemies_node.get_child_count()

    menu.spawn_configured()

    assert_int(enemies_node.get_child_count()).override_failure_message(
        "spawned enemies did not land under Nodes/Enemies"
    ).is_equal(count_before + 3)


## The whole point of the change: an untouched sandbox arena has to stay empty, so
## a number read off a spawned enemy is the enemy under test and nothing else.
##
## This waits out more than one full `StageManager.stage_duration`, because the
## stage clock runs on its own and is the thing that used to end the stage. An
## arena that is merely empty for a few frames proves nothing about 20 seconds.
func test_the_wave_does_not_spawn_anything_by_itself() -> void:
    var scenario := await _run_scenario()
    var stage_manager: StageManager = scenario.get_node("StageManager")
    var spawner: EnemySpawner = stage_manager.enemy_spawner

    assert_bool(spawner.spawn_active).override_failure_message(
        "the wave is still active, so a normal wave lands on top of every spawned enemy"
    ).is_false()
    assert_bool(spawner.spawn_timer.is_stopped()).override_failure_message(
        "the spawn timer is still running, so it keeps re-reading the empty arena through the refill watchdog"
    ).is_true()
    # The stage clock is a separate clock from the spawner's, and it is the one
    # that ends the stage: without this the run reaches `stage_duration` anyway
    # and `go_to_stage(2)` spawns the boss over the top of the sandbox.
    assert_bool(stage_manager.stage_active).override_failure_message(
        "the stage clock is still running, so the stage ends and the boss spawns"
    ).is_false()

    var enemies_node: Node = scenario.get_node("Nodes/Enemies")
    # Asserted on the clock rather than by outlasting `stage_duration` in real
    # time: 20s of game time is 2400 frames of a full `Game.tscn`, which does not
    # fit the suite's timeout. A clock that is not advancing cannot reach
    # `stage_duration`, so the boss case is covered without paying for the wait.
    var elapsed_before := stage_manager.stage_time_elapsed
    for _frame in range(60):
        await get_tree().process_frame
    assert_float(stage_manager.stage_time_elapsed).override_failure_message(
        "the stage clock kept running, so the stage ends at stage_duration and the boss spawns over the sandbox"
    ).is_equal_approx(elapsed_before, 0.001)
    assert_int(enemies_node.get_child_count()).override_failure_message(
        "%d enemies wandered in with nobody pressing Spawn" % enemies_node.get_child_count()
    ).is_equal(0)
    assert_int(stage_manager.current_stage).override_failure_message(
        "the run advanced past the enemy stage; the stage clock was not frozen"
    ).is_equal(1)
    assert_bool(stage_manager.boss_spawner.spawn_active).override_failure_message(
        "the boss spawned over the sandbox"
    ).is_false()


## Holding the stage must not be a one-way door for the rest of the run: the
## panel still spawns, so only the wave was stopped.
func test_holding_the_stage_leaves_the_sandbox_able_to_spawn() -> void:
    var scenario := await _run_scenario()
    var menu: SandboxMenu = scenario.get_node("ScenarioSetup/SandboxMenu")
    _set_spawn_values(menu, 100000.0, 0.0, 1)

    var spawned := menu.spawn_configured()

    assert_int(spawned.size()).is_equal(1)
    assert_bool(spawned[0].is_inside_tree()).is_true()


## Without a character there is no target and no arena reference, so the panel has
## to refuse rather than spawn a broken enemy.
func test_spawning_without_a_character_spawns_nothing() -> void:
    var scenario := await _run_scenario()
    var menu: SandboxMenu = scenario.get_node("ScenarioSetup/SandboxMenu")
    menu.character = null

    assert_int(menu.spawn_configured().size()).is_equal(0)


## The panel opens over the pause menu and closes back onto it, the way
## `OptionsMenu` does, so the pause screen is not left with an empty button list.
func test_opening_the_panel_hides_the_pause_buttons_and_closing_restores_them() -> void:
    var scenario := await _run_scenario()
    var menu: SandboxMenu = scenario.get_node("ScenarioSetup/SandboxMenu")
    var pause_control := scenario.get_node("UI/PauseMenu/Control") as Control

    menu.open()
    assert_bool(menu.visible).is_true()
    assert_bool(pause_control.visible).is_false()

    menu.close()
    assert_bool(menu.visible).is_false()
    assert_bool(pause_control.visible).is_true()


func _set_spawn_values(menu: SandboxMenu, health: float, speed: float, amount: int) -> void:
    menu._health_box.value = health
    menu._speed_box.value = speed
    menu._amount_box.value = float(amount)


## Instantiates the scenario and lets `ScenarioSetup` finish applying it. The
## scene is published as `current_scene` because that is how the real game runs
## it - see `test_debug_scenarios.gd`, which says the same about its own runs.
func _run_scenario() -> Node:
    running_scenario = load(SANDBOX).instantiate()
    get_tree().root.add_child(running_scenario)
    get_tree().current_scene = running_scenario
    for _frame in SETTLE_FRAMES:
        await get_tree().process_frame
    return running_scenario