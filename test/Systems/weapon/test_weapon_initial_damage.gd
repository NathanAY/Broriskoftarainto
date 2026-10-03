# GdUnit TestSuite for a weapon's damage before any stat-change event arrives.
#
# BaseWeapon is a Resource, so a member initializer runs while the object is
# still bare - before Godot writes the `.tres` values into it. `current_damage`
# used to be seeded from `base_damage` there, which baked in the *script default*
# rather than the weapon's configured damage, and nothing recomputed it until an
# `on_stat_changes` event landed. The symptom was a run whose first hit used the
# default 5 damage and every hit after it used the real value.
class_name WeaponInitialDamageTest
extends GdUnitTestSuite

const FIST := "res://src/Resources/weapons/Fist.tres"
const BRAWLER := "res://src/Assets/character/brawler/Brawler.tres"

## The default `BaseWeapon.base_damage`, which a loaded .tres must never report.
const SCRIPT_DEFAULT_DAMAGE := 5.0


func test_loaded_weapon_damage_uses_its_configured_base_damage() -> void:
	var weapon: BaseWeapon = load(FIST)
	assert_float(weapon.base_damage).is_equal(10.0).override_failure_message(
		"Fist.tres changed; this test pins the value the bug was reported against")
	assert_float(weapon.current_damage).is_equal(weapon.base_damage).override_failure_message(
		"a freshly loaded weapon must start on its own base_damage, not the script default")


func test_equipped_weapon_damage_applies_character_stats_before_first_event() -> void:
	var prev_character: Variant = GlobalGameState.starting_character
	var prev_weapons: Array = GlobalGameState.starting_weapons.duplicate()
	var prev_items: Array = GlobalGameState.starting_items.duplicate()
	GlobalGameState.starting_character = BRAWLER
	GlobalGameState.starting_weapons = []
	GlobalGameState.starting_items = []

	var character = load("res://src/Systems/Character.tscn").instantiate()
	add_child(character)
	await get_tree().process_frame

	var wh: WeaponHolder = character.get_node("WeaponHolder")
	var fist: BaseWeapon = wh.weapons[0]
	var stats: Stats = character.get_node("Stats")

	# The point of the test: this is the value the first swing uses, and it must
	# already include the character's damage multiplier. No stat-change event has
	# been emitted since the weapon was equipped.
	var expected := (fist.base_damage + stats.get_stat("flat_damage")) * stats.get_stat("damage")
	assert_float(stats.get_stat("damage")).is_greater(1.0).override_failure_message(
		"brawler is meant to hit harder than the 1.0 baseline, so this test would not catch the bug")
	assert_float(fist.current_damage).is_equal(expected).override_failure_message(
		"the first hit already uses the character's damage stat")

	character.free()
	GlobalGameState.starting_character = prev_character
	GlobalGameState.starting_weapons = prev_weapons
	GlobalGameState.starting_items = prev_items