# GdUnit generated TestSuite
class_name ConfigurePanelTargetTest
extends GdUnitTestSuite

## Covers the one thing that changed in `ConfigurePanel`: who it edits.
##
## The panel used to be the player's panel in every branch - it looked the player
## up from the "character" group and never asked. It can now also be pointed at an
## enemy, so the thing worth pinning is that *every* read goes through the target
## and that nothing leaks back onto the player.

const CONFIGURE_MENU := "res://src/Scenes/menu/ConfigureMenu.tscn"
const PAUSE_MENU := "res://src/Scenes/menu/PauseMenu.tscn"

var panel: CanvasLayer
var player: Character
var enemy: Enemy
var saved_weapons: Array[String]
var saved_items: Array[String]


func before_test() -> void:
    # The panel's player path writes `GlobalGameState`, which outlives the test.
    saved_weapons = GlobalGameState.starting_weapons.duplicate()
    saved_items = GlobalGameState.starting_items.duplicate()


func after_test() -> void:
    GlobalGameState.starting_weapons = saved_weapons
    GlobalGameState.starting_items = saved_items
    panel = null
    player = null
    enemy = null
    collect_orphan_node_details()


## Builds a character and an enemy in the tree, so "closest enemy" and "the
## player" are both real targets rather than stubs. `auto_free` throughout: the
## panel populates and repopulates lists on every edit, and a node freed by hand
## mid-test leaves gdUnit's orphan monitor casting a stale instance out of an
## engine backtrace.
func _spawn_entities() -> void:
    player = auto_free(load("res://src/Systems/Character.tscn").instantiate() as Character)
    add_child(player)
    enemy = auto_free(load("res://src/Systems/Enemy.tscn").instantiate() as Enemy)
    add_child(enemy)


## Opens the panel pointed at `target`, which is the order the pause menu uses:
## set the target, *then* add it to the tree, because `_ready()` populates the
## equipped lists from it.
func _open_panel(target: Node) -> void:
    panel = auto_free(load(CONFIGURE_MENU).instantiate() as CanvasLayer)
    panel.target_entity = target
    add_child(panel)


## The title is how a user tells the two panels apart, so it has to name the
## enemy rather than read as the player's own gear.
func test_title_names_the_enemy_it_was_pointed_at() -> void:
    _spawn_entities()
    _open_panel(enemy)

    assert_str(_title()).override_failure_message(
        "the panel does not say it is editing an enemy, so it reads as the player's gear"
    ).contains("Enemy")


## Repointing an open panel must repaint the title. The pause menu sets the target
## before tree entry, so this order never happens on its own - but a title that
## only refreshes in `_ready()` is a title that lies the moment the target does.
func test_repointing_an_open_panel_updates_the_title() -> void:
    _spawn_entities()
    _open_panel(null)
    assert_str(_title()).contains("Player")

    panel.target_entity = enemy

    assert_str(_title()).override_failure_message(
        "the title still names the player, so the panel shows enemy gear under a player title"
    ).contains("Enemy")


## With no target set the panel is still the player's panel - that is the shipped
## Configure button, unchanged.
func test_unpointed_panel_still_edits_the_player() -> void:
    _spawn_entities()
    _open_panel(null)

    assert_str(_title()).contains("Player")


## A weapon added through the enemy panel must land on the enemy. This is the case
## that was impossible before: the panel only ever looked at the player.
func test_adding_a_weapon_through_the_enemy_panel_equips_the_enemy() -> void:
    _spawn_entities()
    _open_panel(enemy)
    var player_weapons_before := (player.get_node("WeaponHolder") as WeaponHolder).weapons.size()
    # `Enemy._ready()` equips Thorns on itself, so this is a count, not zero.
    var enemy_weapons_before := (enemy.get_node("WeaponHolder") as WeaponHolder).weapons.size()

    panel._on_add_weapon("res://src/Resources/weapons/Pistol.tres", null, null)

    assert_int((enemy.get_node("WeaponHolder") as WeaponHolder).weapons.size()).override_failure_message(
        "the weapon did not reach the enemy"
    ).is_equal(enemy_weapons_before + 1)
    assert_int((player.get_node("WeaponHolder") as WeaponHolder).weapons.size()).override_failure_message(
        "the enemy panel equipped the player instead"
    ).is_equal(player_weapons_before)


## The player fallback appends to `GlobalGameState` for the *next* run. Pointed at
## an enemy that fallback is not a fallback, it is a silent change to the player's
## future loadout.
func test_adding_a_weapon_for_an_enemy_never_touches_the_players_next_run() -> void:
    _spawn_entities()
    _open_panel(enemy)
    var globals_before := GlobalGameState.starting_weapons.size()

    panel._on_add_weapon("res://src/Resources/weapons/Pistol.tres", null, null)

    assert_int(GlobalGameState.starting_weapons.size()).override_failure_message(
        "configuring an enemy changed the player's starting weapons"
    ).is_equal(globals_before)


func test_adding_an_item_through_the_enemy_panel_equips_the_enemy() -> void:
    _spawn_entities()
    _open_panel(enemy)
    var player_items_before := (player.get_node("ItemHolder") as ItemHolder).items.size()

    panel._add_item_to_holder(ItemBuilder.make_stat_item("Test", "+1 damage", {"damage": {"flat": 1.0}}), null)

    assert_int((enemy.get_node("ItemHolder") as ItemHolder).items.size()).override_failure_message(
        "the item did not reach the enemy"
    ).is_equal(1)
    assert_int((player.get_node("ItemHolder") as ItemHolder).items.size()).is_equal(player_items_before)


## Removal is the same read as add, and it is the one that used to leak hardest:
## a panel editing an enemy would remove the *player's* weapon instead.
func test_removing_a_weapon_through_the_enemy_panel_spares_the_player() -> void:
    _spawn_entities()
    _open_panel(enemy)
    var enemy_weapon: BaseWeapon = (enemy.get_node("WeaponHolder") as WeaponHolder).weapons[0]
    var player_weapons_before := (player.get_node("WeaponHolder") as WeaponHolder).weapons.size()

    panel._on_remove_weapon(enemy_weapon, null)

    assert_int((enemy.get_node("WeaponHolder") as WeaponHolder).weapons.size()).is_equal(0)
    assert_int((player.get_node("WeaponHolder") as WeaponHolder).weapons.size()).override_failure_message(
        "removing an enemy's weapon removed the player's instead"
    ).is_equal(player_weapons_before)


## "Clear all" is player-only for the `GlobalGameState` half, for the same reason.
func test_clearing_an_enemy_never_empties_the_players_next_run() -> void:
    _spawn_entities()
    _open_panel(enemy)
    GlobalGameState.starting_weapons = ["res://src/Resources/weapons/Pistol.tres"]
    GlobalGameState.starting_items = ["res://src/Resources/items/BootsOfSpeed.tres"]

    panel._clear_all()

    assert_int(GlobalGameState.starting_weapons.size()).override_failure_message(
        "clearing an enemy emptied the player's next-run loadout"
    ).is_equal(1)
    assert_int((enemy.get_node("ItemHolder") as ItemHolder).items.size()).is_equal(0)


## A freed target must not silently become the player. The arena changes while
## the game runs, and a panel left open on a corpse would show the player's gear
## under an enemy title - so the freed enemy reads as "no target" instead.
func test_a_freed_target_reads_as_no_target_rather_than_the_player() -> void:
    _spawn_entities()
    _open_panel(enemy)
    # Freed outright, which is the case that matters: an enemy killed while the
    # panel is open. The reference is dropped first so nothing here reads it, and
    # `auto_free` is skipped for it - a freed instance left in a backtrace is what
    # makes gdUnit's orphan monitor throw on a cast.
    enemy.free()
    enemy = null

    assert_object(panel._get_target()).override_failure_message(
        "a freed enemy fell back to the player, so the panel would edit the wrong entity"
    ).is_null()


func test_the_pause_menu_offers_a_configure_enemy_button() -> void:
    var pause_menu: Node = load(PAUSE_MENU).instantiate()
    add_child(pause_menu)
    var buttons: Array[Button] = []
    for child in pause_menu.get_node("Control/VBoxContainer").get_children():
        if child is Button:
            buttons.append(child as Button)

    var labels: Array[String] = []
    for button in buttons:
        labels.append(button.text)
    assert_array(labels).override_failure_message(
        "the pause menu has no 'Configure enemy' button, so it is available nowhere"
    ).contains(["Configure enemy"])

    pause_menu.queue_free()


func _title() -> String:
    return (panel.get_node("Control/VBoxContainer/Title") as Label).text