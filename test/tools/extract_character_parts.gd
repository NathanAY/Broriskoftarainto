extends SceneTree

## Dev-only tool: cuts character art parts (body, eyes, mouth) out of the
## generated sheets in `docs/plans/images/sprites/` and writes them onto the
## shared 150x150 character canvas in `src/Assets/character/<id>/`.
##
## Run it from the repo root, naming the character to (re)write, or nothing for
## every character in `PARTS`:
##
##     godot --headless --path . -s res://test/tools/extract_character_parts.gd -- miner
##
## Each part is a hand-picked rectangle of its sheet, trimmed to its opaque
## pixels, scaled and placed on the canvas. The body is as wide as the shared
## potato body and stands on its bottom edge, so the legs and shadow, which the
## scene positions for that body, still line up; the top hat sticks out above.
## Tycoon: a smug monocle pair and a moustache with a smirk. Miner: strapped
## goggles and a toothy grin from the overlay sheet, on the horned grey body
## (bottom right of the bodies sheet), and his mine (top left of the mines
## sheet), fitted edge to edge so `Mine` can scale it to its trigger circle.
##
## The face sheets went through a background remover that also deleted some
## white fills (teeth, and on some sheets the eye whites). Any transparent
## hole the line work *encloses* is filled white again: the hole is found by
## flood-filling transparency in from the crop's border, so whatever the fill
## cannot reach is inside a shape.
##
## Not part of the game: nothing loads this script.

const SPRITES := "res://docs/plans/images/sprites/"
const BODY_SHEET := SPRITES + "A_single_2D_top-down_arena_roguelite_playable_character_body-Photoroom.png"
const FACE_SHEET := SPRITES + "A_sprite_sheet_of_four_separate_2D_cartoon_facial_feature_sp-Photoroom.png"
const POTATO := "res://src/Assets/character/potato.png"
const BODIES_SHEET := SPRITES + "A_sprite_sheet_of_four_separate_2D_top-down_arena_roguelite (2)-Photoroom.png"
const OVERLAY_SHEET := SPRITES + "Only_if_you_keep_the_overlay_systemA_sprite_sheet_of_eight_s (1)-Photoroom.png"
const MINES_SHEET := "res://docs/plans/images/mines/mines_1.png"
const OUT_DIR := "res://src/Assets/character/"

const CANVAS := 150
## A pixel at least this opaque counts as art when trimming and flood-filling.
const SOLID_ALPHA := 0.5

## "<id>/<file>" -> [sheet, source rect, fill holes?, target size on the canvas (the
## longer side is fitted into it), target centre on the canvas]. The centres
## sit right of the body's middle: the existing faces look three-quarter right.
const PARTS := {
	"tycoon/tycoon_body": [BODY_SHEET, Rect2i(0, 0, 1024, 1024), false, Vector2i(0, 0), Vector2i(0, 0)],
	"tycoon/tycoon_eyes": [FACE_SHEET, Rect2i(20, 100, 500, 320), true, Vector2i(46, 30), Vector2i(78, 57)],
	"tycoon/tycoon_mouth": [FACE_SHEET, Rect2i(20, 600, 480, 340), true, Vector2i(36, 24), Vector2i(78, 75)],
	"miner/miner_body": [BODIES_SHEET, Rect2i(540, 560, 484, 464), false, Vector2i(0, 0), Vector2i(0, 0)],
	"miner/miner_eyes": [OVERLAY_SHEET, Rect2i(600, 480, 424, 200), true, Vector2i(58, 26), Vector2i(77, 70)],
	"miner/miner_mine": [MINES_SHEET, Rect2i(30, 50, 230, 220), false, Vector2i(150, 150), Vector2i(75, 75)],
	"miner/miner_mouth": [OVERLAY_SHEET, Rect2i(20, 700, 370, 170), true, Vector2i(22, 10), Vector2i(80, 87)],
}


func _init() -> void:
	var potato := _load(POTATO)
	var footprint := _solid_rect(potato)
	var only := OS.get_cmdline_user_args()
	for part_name: String in PARTS:
		if not only.is_empty() and not only.has(part_name.get_slice("/", 0)):
			continue
		var spec: Array = PARTS[part_name]
		var part := _load(spec[0]).get_region(spec[1])
		part = part.get_region(_solid_rect(part))
		if spec[2]:
			_fill_holes_white(part)
		var box: Vector2i = spec[3]
		var origin: Vector2i
		if box == Vector2i.ZERO:
			# The body: as wide as the potato and standing on the same bottom
			# edge, so the legs line up; a hat or horns stick out above it.
			var body_scale := float(footprint.size.x) / part.get_width()
			part.resize(footprint.size.x, roundi(part.get_height() * body_scale), Image.INTERPOLATE_LANCZOS)
			origin = Vector2i(footprint.position.x, footprint.end.y - part.get_height())
		else:
			var scale := minf(float(box.x) / part.get_width(), float(box.y) / part.get_height())
			part.resize(maxi(1, roundi(part.get_width() * scale)), maxi(1, roundi(part.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
			origin = (spec[4] as Vector2i) - part.get_size() / 2
		var canvas := Image.create(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
		canvas.blend_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), origin)
		var path := OUT_DIR + part_name + ".png"
		if canvas.save_png(path) != OK:
			printerr("extract_character_parts: could not write ", path)
			quit(1)
			return
		print("wrote ", path)
	quit()


func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	return img


func _solid_rect(img: Image) -> Rect2i:
	var rect := Rect2i()
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a >= SOLID_ALPHA:
				rect = Rect2i(x, y, 1, 1) if rect.size == Vector2i.ZERO else rect.expand(Vector2i(x, y)).expand(Vector2i(x + 1, y + 1))
	return rect


func _fill_holes_white(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var outside := PackedByteArray()
	outside.resize(w * h)
	var stack: Array[Vector2i] = []
	for x in w:
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, h - 1))
	for y in h:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		var i := p.y * w + p.x
		if outside[i] == 1 or img.get_pixelv(p).a >= SOLID_ALPHA:
			continue
		outside[i] = 1
		stack.append(p + Vector2i.LEFT)
		stack.append(p + Vector2i.RIGHT)
		stack.append(p + Vector2i.UP)
		stack.append(p + Vector2i.DOWN)
	for y in h:
		for x in w:
			if outside[y * w + x] == 0:
				# Composite the line work over white, so anti-aliased edges keep their shade.
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(1, 1, 1).lerp(Color(c.r, c.g, c.b), c.a))
