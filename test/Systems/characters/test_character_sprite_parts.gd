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


## A source-resolution body is drawn at the character canvas width, and the legs,
## shadow and face parts keep their canvas-size look.
func test_every_body_is_drawn_at_the_canvas_width() -> void:
	for path in _all_character_paths():
		var data: CharacterData = load(path)
		var character := await _spawn_character(path)
		var rig: Sprite2D = character.get_node("Node2D/Sprite2D")
		var holder: Node2D = rig.get_parent()
		var drawn := rig.texture.get_width() * holder.scale.x
		assert_float(drawn).override_failure_message(
			"%s body is drawn %s px wide" % [path, drawn]).is_equal_approx(AssetSizes.CHARACTER_SPRITE * data.body_scale, 0.01)
		var eyes := rig.get_node("eyes") as Sprite2D
		assert_float(eyes.texture.get_width() * eyes.scale.x * holder.scale.x).is_equal_approx(
			float(data.eyes.get_width()) * data.body_scale, 0.01)
		var legs := holder.get_node("Legs") as Node2D
		assert_float(legs.scale.x * holder.scale.x).is_equal_approx(1.0, 0.001)
		character.free()


## The feet offset moves the legs and shadow down and the tint colours the legs,
## and a character with neither keeps the authored scene values.
func test_feet_offset_and_legs_tint_reach_the_rig() -> void:
	var tycoon: CharacterData = load("res://src/Assets/character/tycoon/Tycoon.tres")
	var character := await _spawn_character("res://src/Assets/character/tycoon/Tycoon.tres")
	var holder: Node2D = character.get_node("Node2D")
	var legs := holder.get_node("Legs") as Node2D
	var plain := await _spawn_character(BRAWLER)
	var plain_legs := plain.get_node("Node2D/Legs") as Node2D
	assert_float(legs.position.y * holder.scale.x - plain_legs.position.y).is_equal_approx(
		tycoon.feet_offset_y, 0.01)
	assert_that(legs.modulate).is_equal(tycoon.legs_tint)
	assert_that(plain_legs.modulate).is_equal(Color.WHITE)
	character.free()
	plain.free()


## Minified every frame, so a body wider than the canvas samples its mipmaps.
func test_oversize_body_has_mipmaps_and_mipmapped_filter() -> void:
	for path in _all_character_paths():
		var data: CharacterData = load(path)
		if data.body.get_width() <= int(AssetSizes.CHARACTER_SPRITE):
			continue
		var source := data.body.resource_path + ".import"
		assert_str(FileAccess.get_file_as_string(source)).override_failure_message(
			"%s has no mipmaps" % data.body.resource_path).contains("mipmaps/generate=true")
		var character := await _spawn_character(path)
		var holder: Node2D = character.get_node("Node2D")
		assert_int(holder.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
		character.free()


func test_characters_can_share_a_body_and_differ_by_face() -> void:
	var brawler: CharacterData = load(BRAWLER)
	var soldier: CharacterData = load(SOLDIER)
	# The body is the reusable part; identity comes from the overlays.
	assert_that(brawler.body).is_equal(soldier.body)
	assert_that(brawler.eyes).is_not_equal(soldier.eyes)
	assert_that(brawler.mouth).is_not_equal(soldier.mouth)


## Parts may be reused, but no two characters may end up looking identical.
## Compared by pixels, not by path: a copied PNG under a new name (the Tycoon
## once shipped Ranger's face that way) is still the same look.
func test_no_two_characters_look_identical() -> void:
	var seen := {}
	for path in _all_character_paths():
		var look := []
		for layer in CharacterSprites.layers(load(path)):
			var texture: Texture2D = layer[1]
			look.append(hash(texture.get_image().get_data()))
		var key := str(look)
		assert_bool(seen.has(key)).override_failure_message(
			"%s looks identical to %s" % [path, seen.get(key, "")]).is_false()
		seen[key] = path


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
