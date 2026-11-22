# GdUnit TestSuite for the in-game stat lists.
#
# A modifier-only stat (the regen rates) is not in `Stats.DEFAULT_STATS`, so a
# list built from the base stat keys alone would hide it. These tests pin that a
# non-zero modifier-only stat gets a row and a zero one does not. `armor` is a
# base stat, so it is always listed and its row tracks the live value.
class_name StatsListModifierStatsTest
extends GdUnitTestSuite

const CHARACTER_UI_SCENE := "res://src/ui/CharacterUI.tscn"
const PLAYER_UI_SCENE := "res://src/ui/PlayerUI.tscn"
const SHOP_SCENE := "res://src/Scenes/menu/ShopMenu.tscn"
const ARMOR_ITEM := "res://src/Resources/items/ArmorPlate.tres"
## A real modifier-only stat: published by the regen modifiers, absent from
## `Stats.DEFAULT_STATS`.
const REGEN := "flat_regen_per_second"


func _build_character() -> Character:
	var character := Character.new()
	var event_manager := EventManager.new()
	event_manager.name = "EventManager"
	character.add_child(event_manager)
	var stats := _build_stats(event_manager)
	stats.name = "Stats"
	character.add_child(stats)
	var item_holder := ItemHolder.new()
	item_holder.name = "ItemHolder"
	character.add_child(item_holder)
	var weapon_holder := WeaponHolder.new()
	weapon_holder.name = "WeaponHolder"
	character.add_child(weapon_holder)
	return character


## A Stats node wired to its own EventManager, so `add_modifier` emits instead of
## printing "Stats: No event manager" on every one of these tests.
func _build_stats(event_manager: EventManager) -> Stats:
	var stats := Stats.new()
	stats.event_manager = event_manager
	return stats


## A detached Stats node with a manager of its own, freed with the test.
func _lone_stats() -> Stats:
	var event_manager := EventManager.new()
	event_manager.name = "EventManager"
	var stats := _build_stats(event_manager)
	add_child(event_manager)
	add_child(stats)
	return stats


## Every stat name a list currently shows. Read from the UI's own
## `value_labels` map, which is what holds a row per displayed stat, rather
## than from the row widgets - the two lists build different row shapes (an
## HBox per stat vs a bare Label), the map is the part they share.
func _listed_stats(ui: Node) -> Array[String]:
	var names: Array[String] = []
	for stat_name in ui.value_labels.keys():
		names.append(str(stat_name))
	return names


## The row widget holding `stat_name`, needed for the icon/tooltip assertions.
func _row_for(ui: Control, stat_name: String) -> Control:
	return ui.value_labels[stat_name].get_parent()


func test_display_stat_names_adds_a_non_zero_modifier_only_stat() -> void:
	var stats := _lone_stats()
	stats.add_modifier({REGEN: {"flat": 4.0}})

	# Not a base stat key, so only the modifier puts it on the list.
	assert_bool(stats.stats.has(REGEN)).is_false()
	assert_that(stats.display_stat_names()).contains(REGEN)


func test_display_stat_names_omits_a_zero_modifier_only_stat() -> void:
	var stats := _lone_stats()
	# Two that cancel, so the stat exists on the modifiers but is worth nothing
	# to show.
	stats.add_modifier({REGEN: {"flat": 10.0}})
	stats.add_modifier({REGEN: {"flat": -10.0}})

	assert_float(stats.get_stat(REGEN)).is_zero()
	assert_that(stats.display_stat_names()).not_contains(REGEN)


func test_armor_is_always_listed_as_a_base_stat() -> void:
	var stats := _lone_stats()
	assert_bool(stats.stats.has("armor")).is_true()
	assert_that(stats.display_stat_names()).contains("armor")


func test_display_stat_names_never_lists_the_condition_key() -> void:
	var stats := _lone_stats()
	stats.add_modifier({"damage": {"flat": 1.0}, "condition": {"standing_still": 1.0}})

	assert_that(stats.display_stat_names()).contains("damage")
	assert_that(stats.display_stat_names()).not_contains("condition")
	assert_that(stats.display_stat_names()).not_contains("standing_still")


func test_display_stat_names_does_not_duplicate_a_base_stat() -> void:
	var stats := _lone_stats()
	stats.add_modifier({"health": {"flat": 5.0}})

	var names := stats.display_stat_names()
	assert_int(names.count("health")).is_equal(1)
	assert_float(stats.get_stat("health")).is_equal(Stats.default_stat("health") + 5.0)


func test_character_ui_lists_armor_with_its_value() -> void:
	var character := _build_character()
	var prev_character: Character = GlobalGameState.current_character
	GlobalGameState.current_character = character

	var stats: Stats = character.get_node("Stats")
	stats.add_modifier({"armor": {"flat": 4.0}})

	var ui = load(CHARACTER_UI_SCENE).instantiate()
	add_child(ui)
	await get_tree().process_frame

	assert_that(_listed_stats(ui)).contains("armor")
	# The row shows the live stat value, and armor has a hint to hover.
	var row: Control = _row_for(ui, "armor")
	var label: Label = row.get_child(1)
	assert_str(label.text).is_equal("Armor: 4.00")
	row.emit_signal("mouse_entered")
	assert_str(ui.tooltip.label.text).contains(ItemTooltip.stat_hint("armor"))

	GlobalGameState.current_character = prev_character if is_instance_valid(prev_character) else null
	ui.free()
	character.free()


func test_character_ui_omits_a_zero_modifier_only_stat() -> void:
	var character := _build_character()
	var prev_character: Character = GlobalGameState.current_character
	GlobalGameState.current_character = character

	var stats: Stats = character.get_node("Stats")
	# Declared but flat 0, which is the same as no regen at all.
	stats.add_modifier({REGEN: {"flat": 0.0}})

	var ui = load(CHARACTER_UI_SCENE).instantiate()
	add_child(ui)
	await get_tree().process_frame

	assert_int(ui.stats_container.get_child_count()).is_equal(stats.stats.size())
	assert_that(_listed_stats(ui)).not_contains(REGEN)

	GlobalGameState.current_character = prev_character if is_instance_valid(prev_character) else null
	ui.free()
	character.free()


## Picking up an armor item updates the armor row that was already there.
func test_character_ui_armor_row_tracks_an_armor_item() -> void:
	var character := _build_character()
	var prev_character: Character = GlobalGameState.current_character
	GlobalGameState.current_character = character

	var ui = load(CHARACTER_UI_SCENE).instantiate()
	add_child(ui)
	await get_tree().process_frame
	assert_that(_listed_stats(ui)).contains("armor")

	var stats: Stats = character.get_node("Stats")
	var item_holder: ItemHolder = character.get_node("ItemHolder")
	var armor: Item = load(ARMOR_ITEM)
	item_holder.add_item(armor)
	await get_tree().process_frame

	var label: Label = _row_for(ui, "armor").get_child(1)
	assert_float(stats.get_stat("armor")).is_not_zero()
	assert_str(label.text).is_equal("Armor: %.2f" % stats.get_stat("armor"))

	# Sold: the row stays, back at zero.
	item_holder.remove_item(armor)
	await get_tree().process_frame
	assert_that(_listed_stats(ui)).contains("armor")
	assert_str((_row_for(ui, "armor").get_child(1) as Label).text).is_equal("Armor: 0.00")

	GlobalGameState.current_character = prev_character if is_instance_valid(prev_character) else null
	ui.free()
	character.free()


func test_player_ui_lists_armor() -> void:
	var character := _build_character()
	var prev_character: Character = GlobalGameState.current_character
	GlobalGameState.current_character = character

	var stats: Stats = character.get_node("Stats")
	stats.add_modifier({"armor": {"flat": 4.0}})

	var ui = load(PLAYER_UI_SCENE).instantiate()
	add_child(ui)
	await get_tree().process_frame

	assert_that(_listed_stats(ui)).contains("armor")

	GlobalGameState.current_character = prev_character if is_instance_valid(prev_character) else null
	ui.free()
	character.free()


## The shop's stats panel is a third list, rebuilt after every buy.
func test_shop_menu_shows_armor_bought_from_an_armor_item() -> void:
	var character := _build_character()
	var shop = load(SHOP_SCENE).instantiate()
	add_child(shop)
	shop.character = character
	shop._update_stats()
	assert_that(_listed_stats(shop)).contains("armor")

	character.get_node("ItemHolder").add_item(load(ARMOR_ITEM))
	shop._update_stats()

	var stats: Stats = character.get_node("Stats")
	assert_float(stats.get_stat("armor")).is_not_zero()
	assert_that(_listed_stats(shop)).contains("armor")
	var label: Label = shop.value_labels["armor"]
	assert_str(label.text).is_equal("Armor: %.2f" % stats.get_stat("armor"))

	# Let the rows the rebuild queued for deletion go before the shop does.
	await get_tree().process_frame
	shop.free()
	character.free()


## A base stat keeps updating after the change, so branching on "is this a base
## key" in `_on_stat_changed` did not break the ordinary live-value path.
func test_character_ui_updates_a_base_stat_in_place() -> void:
	var character := _build_character()
	var prev_character: Character = GlobalGameState.current_character
	GlobalGameState.current_character = character

	var ui = load(CHARACTER_UI_SCENE).instantiate()
	add_child(ui)
	await get_tree().process_frame

	var stats: Stats = character.get_node("Stats")
	stats.set_base_stat("health", 99.0)
	await get_tree().process_frame

	var row: Control = _row_for(ui, "health")
	assert_str((row.get_child(1) as Label).text).is_equal("Health: 99.00")

	GlobalGameState.current_character = prev_character if is_instance_valid(prev_character) else null
	ui.free()
	character.free()
