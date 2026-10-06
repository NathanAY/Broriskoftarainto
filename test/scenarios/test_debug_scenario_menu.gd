# GdUnit generated TestSuite
class_name DebugScenarioMenuTest
extends GdUnitTestSuite

## Covers the picker itself: the listed scenes exist, every entry gets a button
## wired to its own index, and each scenario scene carries the setup node that
## gives it its state. What a scenario then *does* to a run is
## `test_debug_scenarios.gd`'s job - the routing is checked through
## `scene_path_for()` rather than by really changing scene, because loading a
## `Game.tscn` mid-suite hands `StageManager` a `current_scene` that is not the
## game and breaks it on the first death.

const MENU_SCENE := "res://test/scenarios/debug_scenario_menu.tscn"

var menu: CanvasLayer
var saved_multiplier: float


func before_test() -> void:
    menu = load(MENU_SCENE).instantiate()
    add_child(menu)
    # The publish tests write a static that outlives the suite, so a later run
    # must not start from whatever they last handed over.
    saved_multiplier = DebugScenarioSetup.pending_monster_multiplier


func after_test() -> void:
    DebugScenarioSetup.pending_monster_multiplier = saved_multiplier
    if is_instance_valid(menu):
        menu.queue_free()
        menu = null
    collect_orphan_node_details()


func test_menu_lists_a_button_per_scenario() -> void:
    assert_int(menu.SCENARIOS.size()).is_greater_equal(3)
    var scenario_list: VBoxContainer = menu.get_node("Control/Center/Menu/ScenarioList")
    for index in menu.SCENARIOS.size():
        var button: Button = scenario_list.get_node_or_null(
            "ScenarioRow%d/ScenarioButton%d" % [index, index]
        )
        assert_object(button).override_failure_message(
            "scenario %d has no button" % index
        ).is_not_null()
        assert_str(button.text).is_equal(menu.SCENARIOS[index]["title"])


func test_every_listed_scenario_scene_exists() -> void:
    for entry in menu.SCENARIOS:
        assert_bool(ResourceLoader.exists(entry["scene"])).override_failure_message(
            "listed scenario scene is missing: %s" % entry["scene"]
        ).is_true()
        assert_str(entry["description"]).is_not_empty()


func test_every_scenario_scene_carries_one_setup_node() -> void:
    # Without its `ScenarioSetup` a scenario silently gives a plain loop-1 run.
    for entry in menu.SCENARIOS:
        var scenario: Node = load(entry["scene"]).instantiate()
        var setups := scenario.find_children("ScenarioSetup", "DebugScenarioSetup", true, false)
        assert_int(setups.size()).override_failure_message(
            "%s has %d ScenarioSetup nodes" % [entry["scene"], setups.size()]
        ).is_equal(1)
        scenario.free()


func test_each_row_routes_to_its_own_scene() -> void:
    for index in menu.SCENARIOS.size():
        assert_str(menu.scene_path_for(index)).is_equal(menu.SCENARIOS[index]["scene"])


func test_each_row_button_opens_its_own_scenario() -> void:
    # The index is bound when the row is built, so a mis-bound button would open a
    # different scenario than the one it is labelled with. `pressed` is connected
    # more than once (`UiMenuButton` adds its own sound hook), so this looks for
    # the menu among the targets rather than counting them.
    var scenario_list: VBoxContainer = menu.get_node("Control/Center/Menu/ScenarioList")
    for index in menu.SCENARIOS.size():
        var button: Button = scenario_list.get_node(
            "ScenarioRow%d/ScenarioButton%d" % [index, index]
        )
        var targets: Array[Node] = []
        for connection in button.get_signal_connection_list(&"pressed"):
            targets.append((connection["callable"] as Callable).get_object())
        assert_bool(menu in targets).override_failure_message(
            "ScenarioButton%d is not wired to the menu: %s" % [index, str(targets)]
        ).is_true()


## An index past the end must not silently load something: it returns nothing and
## the press is refused.
func test_out_of_range_index_is_refused() -> void:
    assert_str(menu.scene_path_for(menu.SCENARIOS.size())).is_empty()


## The slider's own bounds are the contract with `EnemySpawner`: the scenario
## hands the value straight through, so a wider slider than the spawner accepts
## would silently clamp at one end and read as a bug in the scenario.
func test_slider_range_matches_the_spawner_range() -> void:
    var slider: HSlider = menu.get_node("Control/Center/Menu/MonsterRow/MonsterSlider")
    assert_float(slider.min_value).is_equal_approx(EnemySpawner.MIN_SPAWN_MULTIPLIER, 0.001)
    assert_float(slider.max_value).is_equal_approx(EnemySpawner.MAX_SPAWN_MULTIPLIER, 0.001)
    assert_float(menu.MIN_MONSTER_MULTIPLIER).is_equal_approx(
        EnemySpawner.MIN_SPAWN_MULTIPLIER, 0.001
    )
    assert_float(menu.MAX_MONSTER_MULTIPLIER).is_equal_approx(
        EnemySpawner.MAX_SPAWN_MULTIPLIER, 0.001
    )


func test_slider_defaults_to_a_normal_run() -> void:
    assert_float(menu._selected_multiplier()).is_equal_approx(1.0, 0.001)


## The picked density has to reach the scenario. The static is process-wide and
## outlives the test, so every test here sets it rather than relying on a default.
func test_picked_density_is_handed_over() -> void:
    var slider: HSlider = menu.get_node("Control/Center/Menu/MonsterRow/MonsterSlider")
    slider.value = 7.5
    menu._publish_monster_multiplier()
    assert_float(DebugScenarioSetup.pending_monster_multiplier).is_equal_approx(7.5, 0.001)


func test_density_handed_over_is_clamped_to_the_range() -> void:
    var slider: HSlider = menu.get_node("Control/Center/Menu/MonsterRow/MonsterSlider")
    # Set past the slider's own range, which is what a stale value from a
    # previous run of the picker would look like.
    slider.set_value_no_signal(100.0)
    menu._publish_monster_multiplier()
    assert_float(DebugScenarioSetup.pending_monster_multiplier).is_equal_approx(
        EnemySpawner.MAX_SPAWN_MULTIPLIER, 0.001
    )



