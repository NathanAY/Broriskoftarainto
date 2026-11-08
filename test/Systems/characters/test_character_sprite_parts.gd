# GdUnit TestSuite for the layered character rig: `CharacterData.body` / `eyes` /
# `mouth` composed by `CharacterSprites`. A character is a blank body plus face
# overlays authored on the same canvas, so parts are reusable across characters.
# The baked `<id>_icon.png` is no longer drawn anywhere.
class_name CharacterSpritePartsTest
extends GdUnitTestSuite

const CHARACTER_SCENE := "res://src/Systems/Character.tscn"
const BRAWLER := "res://src/Assets/character/brawler/Brawler.tres"
const SOLDIER := "res://src/Assets/character/soldier/Soldier.tres"


func test_every_character_declares_a_body_and_face() -> void:
	var paths := _all_character_paths()
	assert_int(paths.size()).is_greater(0)
	for path in paths:
		var data: CharacterData = load(path)
		assert_that(data.body).override_failure_message(
			"%s has no body part" % path).is_not_null()
		assert_that(data.eyes).override_failure_message(
			"%s has no eyes part" % path).is_not_null()
		assert_that(data.mouth).override_failure_message(
			"%s has no mouth part" % path).is_not_null()


func test_no_character_draws_a_baked_icon() -> void:
	for path in _all_character_paths():
		var data: CharacterData = load(path)
		for layer in CharacterSprites.layers(data):
			var texture: Texture2D = layer[1]
			assert_bool(texture.resource_path.ends_with("_icon.png")).override_failure_message(
				"%s still draws %s" % [path, texture.resource_path]).is_false()


func test_rig_is_composed_from_the_declared_parts() -> void:
	var data: CharacterData = load(BRAWLER)
	var character := await _spawn_character(BRAWLER)

	# The body is the rig's own texture; the face layers are children, so
	# `flip_h` and the hit-flash `modulate` on the rig reach them too.
	var rig: Sprite2D = character.get_node("Node2D/Sprite2D")
	assert_that(rig.texture).is_equal(data.body)
	var eyes := rig.get_node_or_null("eyes") as Sprite2D
	var mouth := rig.get_node_or_null("mouth") as Sprite2D
	assert_that(eyes).is_not_null()
	assert_that(eyes.texture).is_equal(data.eyes)
	assert_that(mouth).is_not_null()
	assert_that(mouth.texture).is_equal(data.mouth)

	character.free()


func test_characters_can_share_a_body_and_differ_by_face() -> void:
	var brawler: CharacterData = load(BRAWLER)
	var soldier: CharacterData = load(SOLDIER)
	# The body is the reusable part; identity comes from the overlays.
	assert_that(brawler.body).is_equal(soldier.body)
	assert_that(brawler.eyes).is_not_equal(soldier.eyes)
	assert_that(brawler.mouth).is_not_equal(soldier.mouth)


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


## Every CharacterData .tres under src/Assets/character.
func _all_character_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	_collect_characters("res://src/Assets/character", paths)
	return paths


func _collect_characters(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_characters(full, out)
		elif entry.ends_with(".tres"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
