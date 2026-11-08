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
	for child in rig.get_children():
		child.free()
	rig.texture = null
	var stack := layers(character)
	for i in range(stack.size()):
		var slot: StringName = stack[i][0]
		var texture: Texture2D = stack[i][1]
		if i == 0:
			rig.texture = texture
			continue
		var layer := Sprite2D.new()
		layer.name = String(slot)
		layer.texture = texture
		rig.add_child(layer)


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
		atlas.region = Rect2(region)
		var rect := TextureRect.new()
		rect.texture = atlas
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		container.add_child(rect)
	return container


## The square crop shared by every layer: the union of the layers' opaque
## pixels, grown to a square around its centre and clamped to the canvas.
static func _portrait_region(stack: Array) -> Rect2i:
	var canvas := Rect2i(Vector2i.ZERO, Vector2i(stack[0][1].get_size()))
	var used := Rect2i()
	var found := false
	for layer in stack:
		var bounds := _opaque_bounds(layer[1])
		if bounds.size.x <= 0 or bounds.size.y <= 0:
			continue
		used = bounds if not found else used.merge(bounds)
		found = true
	if not found:
		return canvas
	var side := maxi(used.size.x, used.size.y)
	var center := used.position + used.size / 2
	var square := Rect2i(center - Vector2i(side, side) / 2, Vector2i(side, side))
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
