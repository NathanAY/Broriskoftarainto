extends SceneTree

## Dev-only tool: cuts the roster creatures out of the enemy sprite sheet and
## writes them into `src/Assets/enemies/` as 100x100 PNGs with the white
## backdrop keyed out.
##
## Run it from the repo root:
##
##     godot --headless --path . -s res://test/tools/extract_enemy_sprites.gd
##
## The sheet is three across and two down, but the grid is not clean: the cells
## are not equal rectangles and the creatures do not sit in the middle of them,
## so slicing it into thirds would cut the turtle's spikes off. The sheet is
## segmented instead. The white backdrop is flood-filled in from the image
## border, which leaves the artwork as the foreground - and leaves any white
## the artwork *encloses*, such as an eye highlight, alone, because the fill
## cannot reach it. The foreground is then split into connected components and
## each one is cropped to its own bounding box.
##
## Not part of the game: nothing loads this script.

const SHEET_PATH := "res://docs/plans/images/enemies/A_sprite_sheet_of_six_enemies.jpg"
const OUT_DIR := "res://src/Assets/enemies/"

## Canvas size for every enemy sprite, per the asset table in
## `docs/visual_style.md`.
const SIZE := 100
## How much of the canvas the creature fills. The asset spec asks for 75-85%.
const FILL := 0.85
## A pixel at least this bright in every channel counts as backdrop.
const BACKDROP_LEVEL := 235
## The sheet is three across and two down.
const GRID_COLUMNS := 3
const GRID_ROWS := 2
## A blob smaller than this is a JPEG speck, not a creature.
const MIN_CREATURE_PIXELS := 4000

## The cells of the sheet that have a name, by output file name. The vector is
## the cell's position in the grid: x is the column, y is the row. A cell is
## listed when its enemy ships, so the sheet's other creatures are not written
## out as art that nothing uses yet.
const CELLS := {
	"bulwark": Vector2i(1, 0),
}


func _init() -> void:
	if not FileAccess.file_exists(SHEET_PATH):
		printerr("extract_enemy_sprites: no sheet at ", SHEET_PATH)
		quit(1)
		return
	var sheet := _load_sheet()
	if sheet == null:
		quit(1)
		return
	sheet.convert(Image.FORMAT_RGBA8)

	var backdrop := _flood_backdrop(sheet.get_data(), sheet.get_width(), sheet.get_height())
	var creatures := _find_creatures(sheet, backdrop)
	# The cells are addressed by position in the grid, so a sheet that segments
	# into the wrong number of blobs would write the wrong creature under the
	# wrong name. Better to stop than to write six wrong PNGs.
	if creatures.size() != GRID_COLUMNS * GRID_ROWS:
		printerr("extract_enemy_sprites: the sheet segmented into %d creatures, expected %d"
			% [creatures.size(), GRID_COLUMNS * GRID_ROWS])
		quit(1)
		return

	for file_name: String in CELLS:
		var cell: Vector2i = CELLS[file_name]
		var creature: Dictionary = creatures[cell.y * GRID_COLUMNS + cell.x]
		var sprite := _cut_out(sheet, backdrop, creature)
		var path: String = OUT_DIR + file_name + ".png"
		var err := sprite.save_png(path)
		if err != OK:
			printerr("extract_enemy_sprites: could not write ", path, " (", err, ")")
			quit(1)
			return
		print("extract_enemy_sprites: wrote %s (%dx%d from %s)" % [
			path, sprite.get_width(), sprite.get_height(),
			_creature_rect(creature)])

	print("extract_enemy_sprites: found %d creatures in the sheet" % creatures.size())
	quit()


## The sheet as an editable image, or null when it cannot be read.
##
## The imported texture is used rather than `Image.load_from_file`, because
## reading the file directly is not something an exported build could do, and
## this tool warns when it does it.
func _load_sheet() -> Image:
	if not ResourceLoader.exists(SHEET_PATH):
		printerr("extract_enemy_sprites: no sheet at ", SHEET_PATH)
		return null
	var texture := load(SHEET_PATH) as Texture2D
	if texture == null:
		printerr("extract_enemy_sprites: could not load ", SHEET_PATH)
		return null
	var image := texture.get_image()
	if image == null:
		printerr("extract_enemy_sprites: could not read the pixels of ", SHEET_PATH)
		return null
	return image


## The creatures in the sheet, in reading order: the top row left to right,
## then the bottom row.
func _find_creatures(image: Image, backdrop: PackedByteArray) -> Array:
	var width := image.get_width()
	var height := image.get_height()
	var blobs := _components(backdrop, width, height)
	# The rows are far apart, so ordering by the vertical centre of the blob
	# separates them without knowing where the grid lines are.
	blobs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _centre(a).y < _centre(b).y)
	var per_row := ceilf(float(blobs.size()) / float(GRID_COLUMNS))
	var rows: Array = []
	var row := 0
	while row < per_row:
		var slice: Array = blobs.slice(row * GRID_COLUMNS, (row + 1) * GRID_COLUMNS)
		slice.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _centre(a).x < _centre(b).x)
		rows.append_array(slice)
		row += 1
	return rows


## The white backdrop, marked by flood-filling in from the image border. Pixels
## the fill cannot reach are the artwork, even when they are white.
func _flood_backdrop(data: PackedByteArray, width: int, height: int) -> PackedByteArray:
	var backdrop := PackedByteArray()
	backdrop.resize(width * height)
	backdrop.fill(0)
	var stack: Array = []
	for x in width:
		_push_backdrop(backdrop, data, stack, width, x, 0)
		_push_backdrop(backdrop, data, stack, width, x, height - 1)
	for y in height:
		_push_backdrop(backdrop, data, stack, width, 0, y)
		_push_backdrop(backdrop, data, stack, width, width - 1, y)
	while not stack.is_empty():
		var point: Vector2i = stack.pop_back()
		var x := point.x
		var y := point.y
		if x > 0:
			_push_backdrop(backdrop, data, stack, width, x - 1, y)
		if x < width - 1:
			_push_backdrop(backdrop, data, stack, width, x + 1, y)
		if y > 0:
			_push_backdrop(backdrop, data, stack, width, x, y - 1)
		if y < height - 1:
			_push_backdrop(backdrop, data, stack, width, x, y + 1)
	return backdrop


func _push_backdrop(backdrop: PackedByteArray, data: PackedByteArray, stack: Array, width: int, x: int, y: int) -> void:
	var index := y * width + x
	if backdrop[index] == 1:
		return
	if not _is_backdrop_pixel(data, index):
		return
	backdrop[index] = 1
	stack.push_back(Vector2i(x, y))


## A pixel counts as backdrop when every channel is bright enough. The sheet is
## a JPEG, so "white" is a band, not a value.
func _is_backdrop_pixel(data: PackedByteArray, index: int) -> bool:
	var base := index * 4
	return data[base] >= BACKDROP_LEVEL \
		and data[base + 1] >= BACKDROP_LEVEL \
		and data[base + 2] >= BACKDROP_LEVEL


## The connected blobs of artwork, each with its bounding box and pixel count.
func _components(backdrop: PackedByteArray, width: int, height: int) -> Array:
	var seen := PackedByteArray()
	seen.resize(width * height)
	seen.fill(0)
	var blobs: Array = []
	for y in height:
		for x in width:
			var index := y * width + x
			if seen[index] == 1 or backdrop[index] == 1:
				continue
			var blob := _grow_blob(backdrop, seen, width, height, Vector2i(x, y))
			seen[index] = 1
			if blob["count"] >= MIN_CREATURE_PIXELS:
				blobs.append(blob)
	return blobs


## One connected blob of artwork, found by walking the artwork from a seed
## pixel.
func _grow_blob(backdrop: PackedByteArray, seen: PackedByteArray, width: int, height: int, start: Vector2i) -> Dictionary:
	var stack: Array = [start]
	var min_x := start.x
	var max_x := start.x
	var min_y := start.y
	var max_y := start.y
	var count := 0
	while not stack.is_empty():
		var point: Vector2i = stack.pop_back()
		count += 1
		min_x = mini(min_x, point.x)
		max_x = maxi(max_x, point.x)
		min_y = mini(min_y, point.y)
		max_y = maxi(max_y, point.y)
		for neighbour: Vector2i in [Vector2i(point.x - 1, point.y), Vector2i(point.x + 1, point.y),
				Vector2i(point.x, point.y - 1), Vector2i(point.x, point.y + 1)]:
			if neighbour.x < 0 or neighbour.y < 0 or neighbour.x >= width or neighbour.y >= height:
				continue
			var index := neighbour.y * width + neighbour.x
			if seen[index] == 1 or backdrop[index] == 1:
				continue
			seen[index] = 1
			stack.push_back(neighbour)
	return {
		"rect": Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1),
		"count": count,
	}


func _centre(blob: Dictionary) -> Vector2:
	var rect: Rect2i = blob["rect"]
	return rect.get_center()


func _creature_rect(blob: Dictionary) -> String:
	var rect: Rect2i = blob["rect"]
	return "%d,%d %dx%d" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


## The creature as a 100x100 sprite with a transparent backdrop.
##
## The backdrop is keyed out and its colour zeroed at the same time, which is
## the premultiplied form: a transparent pixel that still carries the sheet's
## white would be blended into the creature's outline as a pale halo when the
## crop is resized. The result is un-premultiplied again so the sprite carries
## its real colours.
func _cut_out(sheet: Image, backdrop: PackedByteArray, blob: Dictionary) -> Image:
	var rect: Rect2i = blob["rect"]
	var crop := sheet.get_region(rect)
	var sheet_width := sheet.get_width()
	for y in crop.get_height():
		for x in crop.get_width():
			var index := (rect.position.y + y) * sheet_width + (rect.position.x + x)
			if backdrop[index] == 1:
				crop.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))

	var longest := float(maxi(crop.get_width(), crop.get_height()))
	var scale := FILL * float(SIZE) / longest
	var target := Vector2i(
		maxi(1, roundi(float(crop.get_width()) * scale)),
		maxi(1, roundi(float(crop.get_height()) * scale)))
	crop.resize(target.x, target.y, Image.INTERPOLATE_BILINEAR)
	_unpremultiply(crop)

	var sprite := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	sprite.fill(Color(0.0, 0.0, 0.0, 0.0))
	var offset := Vector2i(floori(float(SIZE - target.x) / 2.0), floori(float(SIZE - target.y) / 2.0))
	sprite.blit_rect(crop, Rect2i(Vector2i.ZERO, target), offset)
	return sprite


## Turns a premultiplied image back into straight alpha.
func _unpremultiply(image: Image) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.0:
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue
			if pixel.a >= 1.0:
				continue
			image.set_pixel(x, y, Color(
				clampf(pixel.r / pixel.a, 0.0, 1.0),
				clampf(pixel.g / pixel.a, 0.0, 1.0),
				clampf(pixel.b / pixel.a, 0.0, 1.0),
				pixel.a))
