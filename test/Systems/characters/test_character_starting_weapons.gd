# GdUnit TestSuite for per-character starting weapons (CharacterData.starting_weapons).
class_name CharacterStartingWeaponsTest
extends GdUnitTestSuite

const BRAWLER := "res://src/Assets/character/brawler/Brawler.tres"
const FIST := "res://src/Resources/weapons/Fist.tres"
const RANGER := "res://src/Assets/character/ranger/Ranger.tres"
const PISTOL := "res://src/Resources/weapons/Pistol.tres"
const SPREAD_ITEM := "res://src/Resources/items/SpreadShot.tres"
const SPREAD_SCRIPT := preload("res://src/Systems/Items/modifiers/spread_modifier.gd")
const CHARACTER_SCENE := "res://src/Systems/Character.tscn"


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


# ---------------- the Ranger's spread-firing pistol ----------------

func test_ranger_declares_a_spread_firing_pistol() -> void:
	var data: CharacterData = load(RANGER)
	assert_int(data.starting_weapons.size()).is_equal(1)
	var weapon: BaseWeapon = data.starting_weapons[0]
	# A gun, not a melee or contact weapon...
	assert_bool(weapon is ProjectileWeapon).is_true()
	assert_that(weapon.resource_path).is_equal(PISTOL)
	# ...with the spread shot modifier as part of the identity.
	assert_int(data.starting_items.size()).is_equal(1)
	assert_that(data.starting_items[0].resource_path).is_equal(SPREAD_ITEM)


func test_ranger_equips_the_spread_modifier_on_spawn() -> void:
	var prev_character: Variant = GlobalGameState.starting_character
	var prev_weapons: Array = GlobalGameState.starting_weapons.duplicate()
	var prev_items: Array = GlobalGameState.starting_items.duplicate()
	GlobalGameState.starting_character = RANGER
	GlobalGameState.starting_weapons = []
	GlobalGameState.starting_items = []

	var character: Node = load(CHARACTER_SCENE).instantiate()
	add_child(character)
	await get_tree().process_frame

	var wh: WeaponHolder = character.get_node("WeaponHolder")
	assert_int(wh.weapons.size()).is_equal(1)
	assert_bool(wh.weapons[0] is ProjectileWeapon).is_true()
	# The spread item produced a live Spread modifier node on the holder.
	assert_int(_find_by_script(character.get_node("ItemHolder"), SPREAD_SCRIPT).size()).is_greater(0)

	character.free()
	GlobalGameState.starting_character = prev_character
	GlobalGameState.starting_weapons = prev_weapons
	GlobalGameState.starting_items = prev_items


## Every node under `node` whose script is `script`.
func _find_by_script(node: Node, script: Script) -> Array:
	var found: Array = []
	if node.get_script() == script:
		found.append(node)
	for child in node.get_children():
		found.append_array(_find_by_script(child, script))
	return found