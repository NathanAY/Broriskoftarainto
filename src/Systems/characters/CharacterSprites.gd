class_name CharacterSprites

## The layered character rig, shared by the in-world sprite and the UI icon.
##
## A character is a blank body plus face overlays, all authored on the same
## canvas, so a face from one character can be dropped onto another character's
## body. Order is bottom to top; a missing layer is skipped. A character with no
## body falls back to the shared potato body so the rig is never invisible.
##
## See `docs/visual_style.md` "The character rig".

const DEFAULT_BODY := "res://src/Assets/character/potato.png"

## Meta on the rig's parent holding the fit last applied, so applying twice does
## not compound it.
const FIT_META := &"character_fit"
const FEET_META := &"character_feet"


## Bottom-to-top layers for `character`, as `[slot: StringName, texture: Texture2D]`.
static func layers(character: CharacterData) -> Array:
	var result: Array = []
	var body := _body_texture(character)
	if body != null:
		result.append([&"body", body])
	if character != null:
		if character.eyes != null:
			result.append([&"eyes", character.eyes])
		if character.mouth != null:
			result.append([&"mouth", character.mouth])
	return result


## Rebuilds the rig under `rig`, the `Sprite2D` the idle/move animations scale.
## The body is the rig's own texture so `flip_h`, the damage flash `modulate` and
## the scale animation all reach the face layers through the parent.
static func apply_to_rig(character: CharacterData, rig: Sprite2D) -> void:
	# The shadow is authored under the rig so the idle/move scale reaches it; it is
	# not a face layer, so the rebuild must leave it in place.
	for child in rig.get_children():
		if child.name != &"Shadow":
			child.free()
	rig.texture = null
	var stack := layers(character)
	var fit := _apply_fit(rig, stack, character)
	for i in range(stack.size()):
		var slot: StringName = stack[i][0]
		var texture: Texture2D = stack[i][1]
		if i == 0:
			rig.texture = texture
			continue
		var layer := Sprite2D.new()
		layer.name = String(slot)
		layer.texture = texture
		# Face parts are authored on the character canvas, so they sit at their own
		# size whatever scale the body's fit put on the rig's parent.
		layer.scale = Vector2.ONE / fit
		rig.add_child(layer)


## Draws a source-resolution body at `AssetSizes.CHARACTER_SPRITE` wide, the way an
## enemy sprite is fitted: the scale goes on the rig's **parent**, because the
## idle/move animations write the rig's own `scale` and would overwrite it. What
## else lives under that parent (the legs, the rig's shadow) is authored at
## canvas size, so it is scaled back by the same factor. Returns the fit.
static func _apply_fit(rig: Sprite2D, stack: Array, character: CharacterData) -> float:
	var holder := rig.get_parent() as Node2D
	if holder == null or stack.is_empty():
		return 1.0
	var body: Texture2D = stack[0][1]
	var fit := AssetSizes.scale_for(body, AssetSizes.CHARACTER_SPRITE)
	# `body_scale` shrinks or grows the whole figure (overlays with it); legs and
	# shadow are scaled back below, so they keep their canvas size.
	var total: float = fit * (character.body_scale if character != null else 1.0)
	var applied: float = holder.get_meta(FIT_META, 1.0)
	var change := total / applied
	holder.set_meta(FIT_META, total)
	holder.scale *= change
	# A body taller than the potato's hides the legs and shadow behind it, so the
	# character names how far lower its feet are (canvas pixels).
	var feet: float = character.feet_offset_y if character != null else 0.0
	var feet_applied: float = holder.get_meta(FEET_META, 0.0)
	holder.set_meta(FEET_META, feet)
	var feet_shift := Vector2(0.0, (feet - feet_applied) / total)
	var legs := holder.get_node_or_null("Legs") as Node2D
	if legs != null:
		legs.scale /= change
		legs.position += feet_shift
		legs.modulate = character.legs_tint if character != null else Color.WHITE
	var shadow := rig.get_node_or_null("Shadow") as Node2D
	if shadow != null:
		shadow.scale /= change
		shadow.position = shadow.position / change + feet_shift
	# A texture drawn smaller than its file is minified every frame, so it needs
	# mipmapped sampling or it shimmers while the character moves.
	if body.get_width() > int(AssetSizes.CHARACTER_SPRITE):
		holder.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return fit


## The same stack as a UI icon: one `TextureRect` per layer, anchored full-rect
## on a plate of `plate_size`. All layers share one cropped region, so the face
## stays on the body while the transparent margins around the art are removed -
## otherwise the body fills under half the plate and the portrait reads tiny.
static func make_icon(character: CharacterData, plate_size: Vector2) -> Control:
	var container := Control.new()
	container.custom_minimum_size = plate_size
	var stack := layers(character)
	if stack.is_empty():
		return container
	var region := _portrait_region(stack)
	for layer in stack:
		var atlas := AtlasTexture.new()
		atlas.atlas = layer[1]
		var units := _canvas_units(layer[1])
		atlas.region = Rect2(Vector2(region.position) * units, Vector2(region.size) * units)
		var rect := TextureRect.new()
		rect.texture = atlas
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		container.add_child(rect)
	return container


## Texture pixels per canvas pixel: a 1024px body and a 150px face are the same
## picture, so crops are measured on the canvas and converted per layer.
static func _canvas_units(texture: Texture2D) -> float:
	return float(texture.get_width()) / AssetSizes.CHARACTER_SPRITE


## The square crop shared by every layer, in canvas pixels: the union of the layers' opaque
## pixels, grown to a square around its centre and clamped to the canvas.
static func _portrait_region(stack: Array) -> Rect2i:
	var canvas := Rect2i(Vector2i.ZERO, Vector2i(Vector2(stack[0][1].get_size()) * (1.0 / _canvas_units(stack[0][1]))))
	var used := Rect2i()
	var found := false
	for layer in stack:
		var units := _canvas_units(layer[1])
		var raw := _opaque_bounds(layer[1])
		var bounds := Rect2i(Vector2i(Vector2(raw.position) / units), Vector2i(Vector2(raw.size) / units))
		if bounds.size.x <= 0 or bounds.size.y <= 0:
			continue
		used = bounds if not found else used.merge(bounds)
		found = true
	if not found:
		return canvas
	var side := maxi(used.size.x, used.size.y)
	var center := used.position + Vector2i(int(used.size.x / 2.0), int(used.size.y / 2.0))
	var square := Rect2i(center - Vector2i(int(side / 2.0), int(side / 2.0)), Vector2i(side, side))
	square.position.x = clampi(square.position.x, 0, maxi(0, canvas.size.x - square.size.x))
	square.position.y = clampi(square.position.y, 0, maxi(0, canvas.size.y - square.size.y))
	return square


## Opaque bounds of one layer, cached by path: `get_image()` decompresses the
## texture, and the same handful of part files are measured for every card and
## every hover on the character screen.
static var _bounds_cache: Dictionary = {}


static func _opaque_bounds(texture: Texture2D) -> Rect2i:
	var key := texture.resource_path
	if key != "" and _bounds_cache.has(key):
		return _bounds_cache[key]
	var fits := Rect2i(Vector2i.ZERO, Vector2i(texture.get_size()))
	var image := texture.get_image()
	var bounds := image.get_used_rect() if image != null else fits
	if key != "":
		_bounds_cache[key] = bounds
	return bounds


static func _body_texture(character: CharacterData) -> Texture2D:
	if character != null and character.body != null:
		return character.body
	if ResourceLoader.exists(DEFAULT_BODY):
		return load(DEFAULT_BODY)
	return null
