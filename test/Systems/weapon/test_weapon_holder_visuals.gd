# GdUnit tests for the debug visibility of WeaponHolder weapons.
# A weapon is a Resource, so nothing of it shows up in the scene tree unless the
# holder builds a node for it. These suites pin the debugging contract:
#   - every equipped weapon owns one node named after the weapon
#   - that node is the weapon's own visual (a WeaponVisual) under the WeaponHolder
#   - it sits at the holder's origin, so being under the WeaponHolder is visually neutral
#   - removing a weapon frees its node
#   - two copies of the same weapon get distinct names
class_name WeaponHolderVisualsTest
extends GdUnitTestSuite

const SHOTGUN := "res://src/Resources/weapons/Shotgun.tres"
const PISTOL := "res://src/Resources/weapons/Pistol.tres"

const ORBIT_RADIUS := 60.0
# a lone weapon sits at the holder's angle_offset (-PI), i.e. due left
const ORBIT_OFFSET := Vector2(-ORBIT_RADIUS, 0.0)


func _character_without_weapons() -> Dictionary:
	var runner := scene_runner("res://test/TestScene.tscn")
	var test_scene := runner.scene()
	get_tree().current_scene = test_scene
	var character: Character = test_scene.get_node("Character")
	for weapon in character.weapon_holder.weapons.duplicate():
		character.weapon_holder.remove_weapon(weapon)
	return {"test_scene": test_scene, "character": character}


func test_weapon_owns_one_named_node_under_weapon_holder() -> void:
	var ctx := _character_without_weapons()
	var character: Character = ctx["character"]
	character.weapon_holder.add_weapon(load(SHOTGUN))
	var weapon: BaseWeapon = character.weapon_holder.weapons[0]

	# the weapon reaches its node through itself, no lookup table involved
	var node: WeaponVisual = weapon.sprite_node
	assert_that(node).is_not_null()
	assert_that(node.weapon).is_same(weapon)
	assert_that(node.get_parent()).is_same(character.weapon_holder)
	assert_that(String(node.name)).is_equal("Shotgun")
	assert_that(node.texture).is_equal(weapon.sprite)

	ctx["test_scene"].free()


func test_weapon_visual_keeps_its_position_at_the_holder() -> void:
	var ctx := _character_without_weapons()
	var character: Character = ctx["character"]
	character.weapon_holder.add_weapon(load(SHOTGUN))
	var weapon: BaseWeapon = character.weapon_holder.weapons[0]

	var node: WeaponVisual = weapon.sprite_node
	# being under the WeaponHolder must not offset the weapon from the holder
	assert_that(node.global_position).is_equal(character.global_position + ORBIT_OFFSET)

	ctx["test_scene"].free()


func test_adding_two_identical_weapons_gives_two_named_nodes() -> void:
	var ctx := _character_without_weapons()
	var character: Character = ctx["character"]
	character.weapon_holder.add_weapon(load(SHOTGUN))
	character.weapon_holder.add_weapon(load(SHOTGUN))
	var first: BaseWeapon = character.weapon_holder.weapons[0]
	var second: BaseWeapon = character.weapon_holder.weapons[1]

	assert_that(first.sprite_node).is_not_same(second.sprite_node)
	assert_that(String(first.sprite_node.name)).is_equal("Shotgun")
	assert_that(String(second.sprite_node.name)).is_equal("Shotgun2")

	ctx["test_scene"].free()


func test_removing_weapon_frees_its_node() -> void:
	var ctx := _character_without_weapons()
	var character: Character = ctx["character"]
	character.weapon_holder.add_weapon(load(SHOTGUN))
	character.weapon_holder.add_weapon(load(PISTOL))
	var shotgun: BaseWeapon = character.weapon_holder.weapons[0]
	var pistol: BaseWeapon = character.weapon_holder.weapons[1]
	var shotgun_node: WeaponVisual = shotgun.sprite_node
	var pistol_node: WeaponVisual = pistol.sprite_node

	character.weapon_holder.remove_weapon(shotgun)

	assert_that(shotgun.sprite_node).is_null()
	assert_that(character.weapon_holder.weapons.has(shotgun)).is_false()
	# queue_free only takes effect at the end of the frame, so the node is still
	# parented until then
	assert_that(shotgun_node.is_queued_for_deletion()).is_true()
	# the other weapon is untouched
	assert_that(character.weapon_holder.has_node("Pistol")).is_true()
	assert_that(pistol.sprite_node).is_same(pistol_node)
	assert_that(pistol_node.is_queued_for_deletion()).is_false()

	ctx["test_scene"].free()
