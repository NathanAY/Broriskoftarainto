# With nothing in range a weapon points the way the body sprite faces:
# straight right, or straight left once the sprite is flipped.
class_name WeaponIdleAimTest
extends GdUnitTestSuite

const PISTOL := "res://src/Resources/weapons/Pistol.tres"


func _idle_character() -> Dictionary:
	var runner := scene_runner("res://test/TestScene.tscn")
	var test_scene := runner.scene()
	get_tree().current_scene = test_scene
	# the fixture carries an enemy; remove it so nothing is in range
	var enemy := test_scene.get_node("Enemy")
	test_scene.remove_child(enemy)
	enemy.free()
	var character: Character = test_scene.get_node("Character")
	for weapon in character.weapon_holder.weapons.duplicate():
		character.weapon_holder.remove_weapon(weapon)
	character.weapon_holder.add_weapon(load(PISTOL))
	return {"test_scene": test_scene, "character": character}


func test_idle_weapon_faces_right_then_left_with_the_sprite() -> void:
	var ctx := _idle_character()
	var character: Character = ctx["character"]
	var weapon: BaseWeapon = character.weapon_holder.weapons[0]
	var body := character.get_node("Node2D/Sprite2D") as Sprite2D

	# start from a turned-away pose, as left behind after tracking a target
	weapon.sprite_node.rotation = 1.0
	body.flip_h = false
	weapon.aim()
	assert_float(weapon.sprite_node.rotation).is_equal_approx(0.0, 0.0001)
	assert_bool(weapon.sprite_node.flip_v).is_false()

	body.flip_h = true
	weapon.aim()
	assert_float(absf(weapon.sprite_node.rotation)).is_equal_approx(PI, 0.0001)
	assert_bool(weapon.sprite_node.flip_v).is_true()

	ctx["test_scene"].free()
