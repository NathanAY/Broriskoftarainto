# GdUnit generated TestSuite
class_name ModifierIconSourceSizeTest
extends GdUnitTestSuite

## Modifier icons are source-resolution art: the PNG keeps its authored size and
## `ItemIconGenerator` scales it onto whatever plate the UI draws. These pin both
## halves - the file stays large, and the draw path minifies it with mipmaps -
## because a big file drawn without mipmaps aliases exactly like the first 96px
## portal bake did.

const POISON_ITEM := "res://src/Resources/items/PoisonHit.tres"
const POISON_ICON := "res://src/Assets/modifiers/poisonmodifier.png"
const PLATE: Vector2 = Vector2(64, 64)


func test_modifier_icon_keeps_its_source_resolution() -> void:
	var texture: Texture2D = load(POISON_ICON)
	assert_object(texture).is_not_null()
	assert_int(texture.get_width()).override_failure_message(
		"the poison icon was baked down to the drawn canvas; it is meant to keep "
		+ "its source resolution and be scaled by AssetSizes"
	).is_greater(int(AssetSizes.MODIFIER_ICON))


func test_source_resolution_icon_is_minified_onto_the_plate() -> void:
	var icon := ItemIconGenerator.generate_icon(load(POISON_ITEM), PLATE)
	# One effect scene, so one icon - and no stat icons on this item.
	assert_int(icon.get_child_count()).is_equal(1)
	var rect := icon.get_child(0) as TextureRect
	assert_object(rect).is_not_null()
	assert_vector(icon.custom_minimum_size).is_equal(PLATE)
	assert_int(rect.texture_filter).override_failure_message(
		"a minified source icon needs mipmapped sampling, or it shimmers on the plate"
	).is_equal(CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	icon.free()
