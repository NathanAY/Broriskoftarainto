class_name StageChoiceTest
extends GdUnitTestSuite

## Covers the end-of-run choice: after the shop of `FINAL_BOSS_STAGE` the player
## is offered two world portals — the final boss or another stage — and only
## killing the final boss wins.
##
## The tests drive `StageManager` through its own seams rather than the shop UI:
## the interesting decisions (`_on_shop_next_pressed`, `_end_phase`) are the ones
## a stage boundary goes through, and the portals are spawned from there.

const STAGE_MANAGER := "res://src/Scripts/stage_manager.gd"
const RUN_END_SCREEN := "res://src/Scenes/menu/RunEndScreen.tscn"

var _root: Node = null
var _saved_scene: Node = null


## A minimal runtime tree matching `StageManager`'s `../Nodes/Enemies` contract,
## with both spawners in place. The character is left detached from
## `GlobalGameState` by `_teardown()`.
##
## The manager and its spawners are built **off-tree** and attached as one
## subtree: `StageManager` resolves `$EnemySpawner` / `$BossSpawner` with
## `@onready` and immediately calls `go_to_phase(1)`, so a manager added before
## its spawners has already cached them as null.
##
## The root goes under the tree root, not under this suite: `SceneTree` refuses a
## `current_scene` whose parent is not the root, and `StageManager` reaches the
## world through `get_tree().current_scene`.
func before_test() -> void:
    _saved_scene = get_tree().current_scene
    _root = auto_free(Node.new())
    _root.name = "ChoiceTestRoot"
    get_tree().root.add_child(_root)
    get_tree().current_scene = _root

    var nodes := Node.new()
    nodes.name = "Nodes"
    _root.add_child(nodes)
    var enemies := Node.new()
    enemies.name = "Enemies"
    nodes.add_child(enemies)
    var ui := Node.new()
    ui.name = "UI"
    _root.add_child(ui)

    var character: Character = auto_free(load("res://src/Systems/Character.tscn").instantiate())
    character.name = "Character"
    _root.add_child(character)

    var manager: StageManager = auto_free(load(STAGE_MANAGER).new())
    manager.name = "StageManager"
    manager.character = character

    var boss_spawner: BossSpawner = auto_free(load("res://src/Systems/BossSpawner.tscn").instantiate())
    boss_spawner.name = "BossSpawner"
    boss_spawner.character = character
    boss_spawner.spawn_telegraph_time = 0.0 # these tests read the boss straight after the call
    manager.add_child(boss_spawner)

    var enemy_spawner: EnemySpawner = auto_free(load("res://src/Systems/EnemySpawner.tscn").instantiate())
    enemy_spawner.name = "EnemySpawner"
    enemy_spawner.character = character
    manager.add_child(enemy_spawner)

    _root.add_child(manager)


func after_test() -> void:
    # A leaked pause would freeze every later test in the session.
    get_tree().paused = false
    # The final boss's death slows time; a leaked slow-mo would slow later tests.
    Engine.time_scale = 1.0
    get_tree().current_scene = _saved_scene
    collect_orphan_node_details()


func _manager() -> StageManager:
    return _root.get_node("StageManager") as StageManager


func _enemies() -> Node:
    return _root.get_node("Nodes/Enemies")


func _ui() -> Node:
    return _root.get_node("UI")


## Puts the run past a normal stage: shop exited on the last guaranteed stage, with
## the counters the three spawners/managers share kept in step.
func _finish_stage(stage_number: int) -> void:
    var manager := _manager()
    manager.current_stage = stage_number
    manager.enemy_spawner.current_stage = stage_number
    manager.boss_spawner.current_stage = stage_number
    manager.go_to_phase(StageManager.PHASE_SHOP)
    manager._on_shop_next_pressed()


## The live portals for the end-of-run choice, in tree order. Portals that have
## been answered are only queued for deletion until the end of the frame, so
## they must not count as a still-open question.
func _portals() -> Array[StageChoicePortal]:
    var portals: Array[StageChoicePortal] = []
    for child in _root.get_node("Nodes").get_children():
        if child is StageChoicePortal and not child.is_queued_for_deletion():
            portals.append(child)
    return portals


func _portal(choice: StageChoicePortal.Choice) -> StageChoicePortal:
    for portal in _portals():
        if portal.choice == choice:
            return portal
    return null


## Activates a portal the way `InteractionManager` does on `ui_accept`, and waits
## out its entry animation, after which it has reported its choice.
func _enter(portal: StageChoicePortal) -> void:
    await portal.default_action()


func _run_end_screen() -> RunEndScreen:
    for child in _ui().get_children():
        if child is RunEndScreen:
            return child
    return null


# ------------------------- where the choice is offered ------------------------

## The whole point of the feature: past the last guaranteed stage the run does not
## end by itself, it puts two portals in the world. Before that it must behave
## exactly as it always did.
func test_shop_exit_before_the_final_boss_stage_starts_the_next_stage() -> void:
    _finish_stage(2)

    assert_array(_portals()).override_failure_message(
        "stage 2 must not offer the final boss").is_empty()
    assert_int(_manager().current_stage).is_equal(3)
    assert_int(_manager().current_phase).is_equal(StageManager.PHASE_WAVE)


## Two portals, not a menu panel: they live under `Nodes` with the rest of the
## world and the UI stays untouched.
func test_shop_exit_on_the_final_boss_stage_spawns_two_world_portals() -> void:
    _finish_stage(StageManager.FINAL_BOSS_STAGE)

    var portals := _portals()
    assert_int(portals.size()).override_failure_message(
        "clearing stage %d must offer exactly two portals" % StageManager.FINAL_BOSS_STAGE
    ).is_equal(2)
    assert_object(_portal(StageChoicePortal.Choice.FINAL_BOSS)).is_not_null()
    assert_object(_portal(StageChoicePortal.Choice.EXTRA_STAGE)).is_not_null()
    assert_int(_ui().get_child_count()).override_failure_message(
        "the choice must not be a UI panel").is_equal(0)

    # It waits for the answer: no phase runs and the stage has not advanced.
    assert_bool(_manager().phase_active).is_false()
    assert_int(_manager().current_stage).is_equal(StageManager.FINAL_BOSS_STAGE)
    assert_int(_manager().current_phase).is_equal(StageManager.PHASE_SHOP)


## The Deeper Gate must tell the player the final boss is only postponed, and name
## the phase it leads to; the Finale Gate must say it ends the run.
func test_portal_labels_explain_the_choice() -> void:
    _finish_stage(StageManager.FINAL_BOSS_STAGE)

    var finale := _portal(StageChoicePortal.Choice.FINAL_BOSS).label_text
    var deeper := _portal(StageChoicePortal.Choice.EXTRA_STAGE).label_text
    assert_str(finale).starts_with("Finale Gate")
    assert_str(deeper).starts_with("Deeper Gate")
    assert_str(deeper).contains("Stage %d" % (StageManager.FINAL_BOSS_STAGE + 1))
    assert_str(deeper).contains("Finale can wait")


## Taking an extra stage is the same advance a normal stage boundary does, so all
## three stage counters still have to agree afterwards.
func test_extra_stage_portal_advances_and_offers_the_choice_again() -> void:
    _finish_stage(StageManager.FINAL_BOSS_STAGE)
    await _enter(_portal(StageChoicePortal.Choice.EXTRA_STAGE))

    var manager := _manager()
    assert_int(manager.current_stage).is_equal(StageManager.FINAL_BOSS_STAGE + 1)
    assert_int(manager.enemy_spawner.current_stage).is_equal(StageManager.FINAL_BOSS_STAGE + 1)
    assert_int(manager.boss_spawner.current_stage).is_equal(StageManager.FINAL_BOSS_STAGE + 1)
    assert_int(manager.current_phase).is_equal(StageManager.PHASE_WAVE)

    # Banked stage 4, cleared it, and the question comes back rather than the run
    # silently continuing or ending.
    manager.go_to_phase(StageManager.PHASE_SHOP)
    manager._on_shop_next_pressed()
    assert_int(_portals().size()).is_equal(2)
    assert_int(manager.current_stage).is_equal(StageManager.FINAL_BOSS_STAGE + 1)


## Picking one answer has to remove *both* portals: the question is over.
func test_both_portals_go_away_once_answered() -> void:
    _finish_stage(StageManager.FINAL_BOSS_STAGE)
    var portals := _portals()
    var chosen := _portal(StageChoicePortal.Choice.EXTRA_STAGE)
    await _enter(chosen)

    # `queue_free()` only marks the node; the removal lands at the end of the
    # frame, so one `process_frame` await would resume before it happened.
    for _frame in 3:
        await get_tree().process_frame

    for portal in portals:
        assert_bool(is_instance_valid(portal)).override_failure_message(
            "both portals must not survive the answer").is_false()
    assert_array(_portals()).override_failure_message(
        "a freed portal must not still be a child of Nodes").is_empty()
    assert_array(_manager().stage_portals).is_empty()


# ------------------------------ what each answer does -------------------------

## The final boss is a real fight, not a win screen: the portal picks it, a boss
## spawns, and the run is still going.
func test_final_boss_portal_spawns_a_boss_and_does_not_win_yet() -> void:
    _finish_stage(StageManager.FINAL_BOSS_STAGE)
    await _enter(_portal(StageChoicePortal.Choice.FINAL_BOSS))

    var manager := _manager()
    assert_int(manager.current_phase).is_equal(StageManager.PHASE_FINAL_BOSS)
    assert_bool(manager.phase_active).is_true()
    assert_bool(manager.boss_spawner.spawn_active).is_true()
    assert_bool(manager.boss_spawner.boss_instance != null).override_failure_message(
        "choosing the final boss must spawn it").is_true()
    assert_int(_enemies().get_child_count()).is_greater(0)
    assert_object(_run_end_screen()).override_failure_message(
        "the run is not won until the final boss dies").is_null()


## ...and killing it wins. `_end_phase()` is what the empty arena triggers.
func test_killing_the_final_boss_wins_the_run() -> void:
    _finish_stage(StageManager.FINAL_BOSS_STAGE)
    await _enter(_portal(StageChoicePortal.Choice.FINAL_BOSS))

    for enemy in _enemies().get_children():
        enemy.free()
    _manager()._end_phase()

    assert_object(_run_end_screen()).override_failure_message(
        "the final boss dying is the win condition").is_not_null()
    assert_str(_run_end_screen().label.text).is_equal("YOU WIN!")


## A normal boss must still lead to the shop, not to the win screen - the stage-3
## boss is not the final one.
func test_clearing_an_ordinary_boss_opens_the_shop() -> void:
    var manager := _manager()
    manager.current_stage = 3
    manager.go_to_phase(StageManager.PHASE_BOSS)

    for enemy in _enemies().get_children():
        enemy.free()
    manager._end_phase()

    assert_int(manager.current_phase).is_equal(StageManager.PHASE_SHOP)
    assert_object(_run_end_screen()).is_null()


# ------------------- the real shop -> portals chain ---------------------------

## The unit tests above call `_on_shop_next_pressed()` directly. This one closes
## the stage through the actual wiring: `ShopMenu`'s own **Go next** button, its
## `next_stage_pressed` signal, and the one-shot connection `StageManager` makes
## when it spawns the portal. That chain is what a player actually hits, and it
## is the only place a duplicate/missing connection would show up.
func test_shop_go_next_button_spawns_the_choice_portals() -> void:
    var manager := _manager()
    manager.current_stage = StageManager.FINAL_BOSS_STAGE
    manager.enemy_spawner.current_stage = StageManager.FINAL_BOSS_STAGE
    manager.boss_spawner.current_stage = StageManager.FINAL_BOSS_STAGE

    var shop: ShopMenu = load("res://src/Scenes/menu/ShopMenu.tscn").instantiate()
    shop.name = "ShopMenu"
    var factory: ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
    _root.add_child(factory)
    shop.item_factory = factory
    _ui().add_child(shop)

    # `spawn_shop_portal()` is what connects the signal; the portal itself needs
    # no assertions here.
    manager.spawn_shop_portal()
    for portal in _root.get_node("Nodes").get_children():
        portal.free()

    # Phase 2 reveals Go next, which is the button the player presses.
    shop.show_menu()
    shop.load_items([])
    assert_bool(shop.next_stage_button.visible).is_true()
    shop.next_stage_button.pressed.emit()

    assert_int(_portals().size()).override_failure_message(
        "the shop's Go next must spawn the choice portals").is_equal(2)
    assert_int(manager.current_stage).is_equal(StageManager.FINAL_BOSS_STAGE)


# ------------------------------- boss scaling ---------------------------------

## The final boss has to be harder than the stage that led to it, or choosing it
## would be a free win. This is the mechanic, not a number: the same boss scene
## scaled by more stages.
func test_final_boss_is_scaled_past_the_stage_that_reached_it() -> void:
    var manager := _manager()
    manager.current_stage = StageManager.FINAL_BOSS_STAGE
    manager.boss_spawner.current_stage = StageManager.FINAL_BOSS_STAGE
    var spawner := manager.boss_spawner
    var growth: float = spawner.health_growth_per_stage
    var plain_stage_hp: float = _boss_health_at(spawner, StageManager.FINAL_BOSS_STAGE)

    manager.go_to_phase(StageManager.PHASE_FINAL_BOSS)
    var final_hp: float = spawner.boss_instance.stats.stats["health"]

    assert_float(final_hp).override_failure_message(
        "the final boss must out-scale the stage-%d boss" % StageManager.FINAL_BOSS_STAGE
    ).is_greater(plain_stage_hp)
    # Explicitly proportional: the extra is `final_boss_extra_stages` stages of the
    # same growth, so a hardcoded figure would fail here.
    assert_float(final_hp).is_equal_approx(
        plain_stage_hp + growth * spawner.final_boss_extra_stages, 0.001)


## The final boss is its own scripted fight: the final scene with a `BossBrain`,
## not the stage boss with a bigger shotgun loadout.
func test_final_boss_is_the_scripted_fight_without_a_loadout() -> void:
    var manager := _manager()
    manager.current_stage = StageManager.FINAL_BOSS_STAGE
    manager.boss_spawner.current_stage = StageManager.FINAL_BOSS_STAGE

    manager.go_to_phase(StageManager.PHASE_FINAL_BOSS)
    var boss: Enemy = manager.boss_spawner.boss_instance

    assert_str(boss.scene_file_path).is_equal(manager.boss_spawner.final_boss_scene.resource_path)
    assert_object(boss.behaviour).is_instanceof(BossBrain)
    # Only the contact weapon: the attacks replace the shotgun ramp.
    assert_int(boss.weapon_holder.weapons.size()).is_equal(1 if boss.contact_weapon != null else 0)


## The loadout ramp is capped, so a boss scaled far past the normal run carries a
## budgeted number of weapons instead of one pair per stage. Asserted as
## "past the cap is identical to at the cap", so the figure that counts is the
## cap itself and not the boss's contact weapon or a hand-written total.
func test_final_boss_loadout_stops_growing_at_the_cap() -> void:
    var spawner := _manager().boss_spawner
    var at_cap: int = _boss_weapon_count_at(spawner, BossSpawner.LOADOUT_STAGE_CAP)
    var far_past: int = _boss_weapon_count_at(spawner, BossSpawner.LOADOUT_STAGE_CAP + 20)

    assert_int(far_past).override_failure_message(
        "the loadout ramp kept growing past LOADOUT_STAGE_CAP"
    ).is_equal(at_cap)
    # ...but the cap is not zero weapons: the ramp still has to reach it.
    assert_int(at_cap).is_greater(0)


## Instantiates a boss at `stage` and returns how many weapons it ended up with,
## then clears it so the next call is not blocked by the "already spawned" guard.
func _boss_weapon_count_at(spawner: BossSpawner, stage: int) -> int:
    spawner.current_stage = stage
    spawner.spawn_boss()
    var count: int = spawner.boss_instance.weapon_holder.weapons.size()
    spawner.boss_instance.free()
    spawner.boss_instance = null
    return count


## Builds a boss at `stage` in an isolated spawner and returns its base health, so
## the final-boss assertion can compare two real scalings instead of a literal.
func _boss_health_at(spawner: BossSpawner, stage: int) -> float:
    spawner.current_stage = stage
    spawner.spawn_boss()
    var hp: float = spawner.boss_instance.stats.stats["health"]
    # Reset so the caller's next spawn is not blocked by the "already spawned"
    # guard.
    spawner.boss_instance.free()
    spawner.boss_instance = null
    return hp
