# GdUnit TestSuite for the ground shadow under the Character. The shadow is a child
# of the rig `Node2D/Sprite2D`, the node the idle and move animations scale, so it
# grows and shrinks with the body. `show_behind_parent` keeps it under the body.
class_name CharacterShadowTest
extends GdUnitTestSuite

const CHARACTER_SCENE := "res://src/Systems/Character.tscn"
const BRAWLER := "res://src/Assets/character/brawler/Brawler.tres"


func test_character_has_a_translucent_ground_shadow() -> void:
	var character := await _spawn_character(BRAWLER)

	var shadow := character.get_node_or_null("Node2D/Sprite2D/Shadow") as Sprite2D
	assert_that(shadow).is_not_null()
	assert_float(shadow.modulate.a).is_greater(0.0).is_less(1.0)

	character.free()


func test_shadow_rides_on_the_animated_rig_and_draws_behind_it() -> void:
	var character := await _spawn_character(BRAWLER)

	var rig: Node = character.get_node("Node2D/Sprite2D")
	var shadow: Node = rig.get_node("Shadow")
	assert_that(shadow.get_parent()).is_equal(rig)
	assert_bool(shadow.show_behind_parent).is_true()

	character.free()


func test_shadow_is_a_flat_circle_stretched_into_an_oval() -> void:
	var character := await _spawn_character(BRAWLER)

	var shadow := character.get_node("Node2D/Sprite2D/Shadow") as Sprite2D
	# A square texture scaled non-uniformly: the same width and height as a circle,
	# squashed vertically, so the shadow reads as a ground oval.
	assert_that(shadow.texture.get_width()).is_equal(shadow.texture.get_height())
	assert_float(shadow.scale.y).is_less(shadow.scale.x)
	# The ground sits below the body's centre, so the shadow is below the origin.
	assert_float(shadow.position.y).is_greater(0.0)

	character.free()


func test_shadow_survives_the_rig_being_rebuilt_from_character_data() -> void:
	# Spawning with a CharacterData runs CharacterSprites.apply_to_rig, which
	# rebuilds the rig's face layers. The shadow must not be freed by that rebuild.
	var character := await _spawn_character(BRAWLER)

	assert_that(character.get_node_or_null("Node2D/Sprite2D/Shadow")).is_not_null()
	assert_that(character.get_node_or_null("Node2D/Sprite2D/eyes")).is_not_null()

	character.free()


func _spawn_character(character_path: String) -> Node:
	var prev_character: Variant = GlobalGameState.starting_character
	var prev_weapons: Array = GlobalGameState.starting_weapons.duplicate()
	var prev_items: Array = GlobalGameState.starting_items.duplicate()
	GlobalGameState.starting_character = character_path
	GlobalGameState.starting_weapons = []
	GlobalGameState.starting_items = []

	var character: Node = load(CHARACTER_SCENE).instantiate()
	add_child(character)
	await get_tree().process_frame

	GlobalGameState.starting_character = prev_character
	GlobalGameState.starting_weapons = prev_weapons
	GlobalGameState.starting_items = prev_items
	return character
