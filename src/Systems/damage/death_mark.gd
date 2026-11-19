class_name DeathMark
extends Sprite2D

## The stain an enemy leaves where it died. `setup()` picks one cell of a 4x4
## decal sheet, so hundreds of marks on the floor do not read as one stamp.
##
## Every `.png` in `SHEET_DIR` is a sheet; drop a new one in and it is used. The
## colour of each cell is measured, not listed: a cell that averages red, green
## or purple is a coloured decal, any other cell (grey, brown, bone) is generic.
## An enemy gets a coloured decal of its own colour only some of the time, and a
## generic one otherwise. The enemy's colour is measured from its sprite the same way.
##
## Measuring walks every pixel, so it runs on worker threads and is started early:
## `warm_up()` for the sheets and `request_tint()` for an enemy's sprite are both
## called when an enemy is created, long before one dies.

enum Tint { NONE, RED, GREEN, PURPLE }

const SCENE_PATH := "res://src/Systems/damage/DeathMark.tscn"
const SHEET_DIR := "res://src/Assets/death_marks/"
## Cells per row and per column of a sheet; the scene's `hframes` / `vframes` match.
const GRID := 4
## An image area (one sheet cell, or a whole sprite) is sampled on a grid this
## many points across, not read pixel by pixel: an average colour and a rough
## bounding box do not need every pixel.
const SAMPLES_PER_SIDE := 20
## Chance that an enemy with a tint uses a coloured decal rather than a generic one.
const TINTED_CHANCE := 0.5

## The decal is this fraction of the enemy's art width, so a swarmer and a boss
## leave stains in the same proportion to their bodies.
const WIDTH_RATIO := 0.7
const SIZE_JITTER := 0.1
## The art has a fixed light direction, so it may only tilt a little.
const MAX_TILT_DEG := 15.0

## Colour bands of the average colour (HSV hue 0..1). Less saturated than
## `MIN_SATURATION` (grey, olive, brown) or outside every band (orange, yellow,
## blue) counts as `NONE`: no coloured decal suits it.
const MIN_SATURATION := 0.18
const GREEN_HUE := Vector2(0.15, 0.45)
const PURPLE_HUE := Vector2(0.68, 0.92)
const RED_HUE_MAX := 0.03
const RED_HUE_MIN := 0.95

## Finished tint per sprite texture.
static var _tint_cache := {}
## Scans still running: texture -> `{task, result}`. The task writes `result[0]`,
## and only a finished task's result is read.
static var _tint_pending := {}
## Every decal in `SHEET_DIR`: `{texture, frame, tint, content_px}`.
static var _decals: Array = []
static var _warm_started := false
## Sheet files not yet read back from the GPU, one is taken per frame.
static var _sheet_queue: Array = []
## Sheets being measured on workers: `{task, found}`. A worker fills `found`, and
## it is only read after the task is waited on.
static var _sheet_jobs: Array = []


## Starts measuring the decal sheets, if that has not happened.
##
## Reading a texture back (`get_image()`) is a rendering-server call: it stalls the
## frame it runs on, and it cannot run on a worker while the main thread waits on
## that worker, which deadlocks. So the reads stay on the main thread, one sheet
## per frame so none of them is a visible hitch, and only the pixel sampling goes
## to `WorkerThreadPool`.
static func warm_up() -> void:
	if _warm_started:
		return
	_warm_started = true
	for file_name in ResourceLoader.list_directory(SHEET_DIR):
		if file_name.get_extension() == "png":
			_sheet_queue.append(SHEET_DIR + file_name)
	_read_next_sheet()


## Every decal found in `SHEET_DIR`, each with its measured tint and the width of
## its art inside the cell (`content_px`, in sheet pixels). If the warm-up has not
## finished it finishes here, which only happens when a mark is needed within the
## first few frames of the run.
static func decals() -> Array:
	warm_up()
	while not _sheet_queue.is_empty():
		_read_next_sheet()
	for job: Dictionary in _sheet_jobs:
		WorkerThreadPool.wait_for_task_completion(job.task)
		_decals.append_array(job.found)
	_sheet_jobs.clear()
	return _decals


## Reads one queued sheet and hands its pixels to a worker; the next sheet is read
## on the next frame.
static func _read_next_sheet() -> void:
	if _sheet_queue.is_empty():
		return
	var sheet := load(_sheet_queue.pop_front()) as Texture2D
	var image := sheet.get_image() if sheet != null else null
	if image != null:
		var found: Array = []
		var task := WorkerThreadPool.add_task(_scan_sheet.bind(sheet, image, found), false, "death mark decals")
		_sheet_jobs.append({"task": task, "found": found})
	var next_frame: Signal = Engine.get_main_loop().process_frame
	if not _sheet_queue.is_empty() and not next_frame.is_connected(_read_next_sheet):
		next_frame.connect(_read_next_sheet, CONNECT_ONE_SHOT)


## Starts measuring an enemy's sprite on a worker thread. Cheap to call again.
static func request_tint(sprite_texture: Texture2D) -> void:
	if sprite_texture == null or _tint_cache.has(sprite_texture) or _tint_pending.has(sprite_texture):
		return
	var image := sprite_texture.get_image()
	if image == null:
		_tint_cache[sprite_texture] = Tint.NONE
		return
	var result: Array = [Tint.NONE]
	var task := WorkerThreadPool.add_task(_scan_tint.bind(image, result), false, "enemy tint")
	_tint_pending[sprite_texture] = {"task": task, "result": result}


## The tint of an enemy, from the average colour of its sprite's opaque pixels.
## A scan that has not finished yet reads as `NONE` (a generic decal) rather than
## stalling the death; `wait_for_scan` blocks instead, for tests.
static func tint_of(sprite_texture: Texture2D, wait_for_scan := false) -> Tint:
	if sprite_texture == null:
		return Tint.NONE
	request_tint(sprite_texture)
	if _tint_pending.has(sprite_texture):
		var job: Dictionary = _tint_pending[sprite_texture]
		if not wait_for_scan and not WorkerThreadPool.is_task_completed(job.task):
			return Tint.NONE
		WorkerThreadPool.wait_for_task_completion(job.task)
		_tint_cache[sprite_texture] = job.result[0]
		_tint_pending.erase(sprite_texture)
	return _tint_cache.get(sprite_texture, Tint.NONE)


## Puts a corpse decal where `dead` died. Shared by every kind of enemy, so the
## boss leaves one too. Placed on the next idle frame: the death handler runs in
## the middle of a physics step.
static func leave_corpse(dead: Node2D) -> void:
	var enemy_sprite = dead.get("sprite")
	var tint := tint_of(enemy_sprite.texture) if enemy_sprite != null else Tint.NONE
	var width = dead.get("art_width")
	_place.bind(dead.get_tree(), dead.global_position, tint,
		AssetSizes.ENEMY_SPRITE if width == null else width).call_deferred()


static func _place(tree: SceneTree, where: Vector2, tint: Tint, enemy_width: float) -> void:
	var parent := tree.current_scene.get_node_or_null("Nodes/death_marks") if tree.current_scene != null else null
	if parent == null:
		return
	var mark: DeathMark = (load(SCENE_PATH) as PackedScene).instantiate()
	mark.setup(tint, enemy_width)
	mark.global_position = where
	parent.add_child(mark)


## Worker thread: measures every cell of one sheet.
static func _scan_sheet(sheet: Texture2D, image: Image, found: Array) -> void:
	if image.is_compressed():
		image.decompress()
	var cell := int(image.get_width() / float(GRID))
	for cell_index in GRID * GRID:
		var rect := Rect2i((cell_index % GRID) * cell, floori(float(cell_index) / GRID) * cell, cell, cell)
		var measured := _measure(image, rect)
		if measured.content <= 0.0:
			continue
		found.append({
			"texture": sheet,
			"frame": cell_index,
			"tint": measured.tint,
			"content_px": measured.content,
		})


## Worker thread: measures one enemy sprite.
static func _scan_tint(image: Image, result: Array) -> void:
	if image.is_compressed():
		image.decompress()
	result[0] = _measure(image, Rect2i(Vector2i.ZERO, image.get_size())).tint


## The tint of the opaque pixels in `rect`, and how wide their bounding box is,
## from a grid of `SAMPLES_PER_SIDE` points rather than every pixel.
static func _measure(image: Image, rect: Rect2i) -> Dictionary:
	var step := maxf(1.0, float(mini(rect.size.x, rect.size.y)) / SAMPLES_PER_SIDE)
	var sum := Vector3.ZERO
	var count := 0
	var low := Vector2(rect.end)
	var high := Vector2(rect.position)
	var y := float(rect.position.y)
	while y < rect.end.y:
		var x := float(rect.position.x)
		while x < rect.end.x:
			var pixel := image.get_pixel(int(x), int(y))
			if pixel.a > 0.5:
				sum += Vector3(pixel.r, pixel.g, pixel.b)
				count += 1
				low = Vector2(minf(low.x, x), minf(low.y, y))
				high = Vector2(maxf(high.x, x + step), maxf(high.y, y + step))
			x += step
		y += step
	if count == 0:
		return {"tint": Tint.NONE, "content": 0.0}
	return {
		"tint": _classify(Color(sum.x / count, sum.y / count, sum.z / count)),
		"content": maxf(high.x - low.x, high.y - low.y),
	}


static func _classify(average: Color) -> Tint:
	if average.s < MIN_SATURATION:
		return Tint.NONE
	if average.h <= RED_HUE_MAX or average.h >= RED_HUE_MIN:
		return Tint.RED
	if average.h >= GREEN_HUE.x and average.h <= GREEN_HUE.y:
		return Tint.GREEN
	if average.h >= PURPLE_HUE.x and average.h <= PURPLE_HUE.y:
		return Tint.PURPLE
	return Tint.NONE


## Chooses the decal for an enemy of this tint and art width.
func setup(tint: Tint, enemy_width: float) -> void:
	var wanted := Tint.NONE
	if tint != Tint.NONE and randf() < TINTED_CHANCE:
		wanted = tint
	var pool := decals().filter(func(candidate: Dictionary) -> bool: return candidate.tint == wanted)
	if pool.is_empty():
		pool = decals().filter(func(candidate: Dictionary) -> bool: return candidate.tint == Tint.NONE)
	var decal: Dictionary = pool.pick_random()
	texture = decal.texture
	frame = decal.frame
	scale = Vector2.ONE * enemy_width * WIDTH_RATIO / decal.content_px \
		* randf_range(1.0 - SIZE_JITTER, 1.0 + SIZE_JITTER)
	rotation = deg_to_rad(randf_range(-MAX_TILT_DEG, MAX_TILT_DEG))
