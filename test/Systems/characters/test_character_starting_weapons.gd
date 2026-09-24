# GdUnit TestSuite for per-character starting weapons (CharacterData.starting_weapons).
class_name CharacterStartingWeaponsTest
extends GdUnitTestSuite

const BRAWLER := "res://src/Assets/character/brawler/Brawler.tres"
const FIST := "res://src/Resources/weapons/Fist.tres"


func test_character_data_supports_starting_weapons() -> void:
	var res: CharacterData = load(BRAWLER)
	assert_object(res).is_not_null()
	assert_int(res.starting_weapons.size()).is_equal(1)
	var weapon: BaseWeapon = res.starting_weapons[0]
	assert_that(weapon).is_not_null()
	assert_that(weapon.name).is_equal("Fist")


func test_brawler_tooltip_shows_starting_weapon() -> void:
	var res: CharacterData = load(BRAWLER)
	var lines := CharacterTooltip.tooltip_lines(res)
	assert_str("\n".join(lines)).contains("starting weapon: Fist")


func test_initializer_equips_starting_weapon_on_spawn() -> void:
	var prev_character: Variant = GlobalGameState.starting_character
	var prev_weapons: Array = GlobalGameState.starting_weapons.duplicate()
	var prev_items: Array = GlobalGameState.starting_items.duplicate()
	GlobalGameState.starting_character = BRAWLER
	GlobalGameState.starting_weapons = []
	GlobalGameState.starting_items = []

	var character = load("res://src/Systems/Character.tscn").instantiate()
	add_child(character)
	# Starting weapons are applied via call_deferred after the ready pass.
	await get_tree().process_frame

	var wh: WeaponHolder = character.get_node("WeaponHolder")
	assert_int(wh.weapons.size()).is_greater(0)
	var has_fist := false
	for w in wh.weapons:
		if w is BaseWeapon and w.name == "Fist":
			has_fist = true
	assert_bool(has_fist).is_true()

	character.free()
	GlobalGameState.starting_character = prev_character
	GlobalGameState.starting_weapons = prev_weapons
	GlobalGameState.starting_items = prev_items