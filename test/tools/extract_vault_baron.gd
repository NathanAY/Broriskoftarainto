extends SceneTree

## Dev-only tool: cuts the Vault Baron (the final boss) out of the generated art
## in `docs/plans/images/boss/` and writes the game sprites into
## `src/Assets/enemies/` and `src/Assets/boss/`.
##
## Run it from the repo root:
##
##     godot --headless --path . -s res://test/tools/extract_vault_baron.gd
##
## The backgrounds were removed before the files came in, so this only trims.
## The two boss bodies (vault shut / vault burst) are cut with the **same**
## rectangle - the union of both silhouettes - so the phase-3 texture swap
## lands exactly on top of the phase-1 one instead of jumping.
## The props sheet is a 2x2 grid; each prop is cut from its quadrant and trimmed.
##
## Not part of the game: nothing loads this script.

const SRC := "res://docs/plans/images/boss/"
const BODY := SRC + "vault_baron_source.png"
const BROKEN := SRC + "vault_baron_broken_source.png"
const PROPS := SRC + "vault_baron_props_source.png"

## A pixel at least this opaque counts as art when trimming.
const SOLID_ALPHA := 0.06

## prop name -> quadrant of the 1024 sheet it is cut from.
const PROP_CELLS := {
	"boss_coin": Rect2i(0, 0, 540, 500),
	"boss_safe": Rect2i(540, 0, 484, 500),
	"burrow_mound": Rect2i(0, 520, 560, 504),
	"money_sack": Rect2i(560, 520, 464, 504),
}


func _init() -> void:
	var body := _load(BODY)
	var broken := _load(BROKEN)
	var both := _solid_rect(body).merge(_solid_rect(broken))
	_save(body.get_region(both), "res://src/Assets/enemies/vault_baron.png")
	_save(broken.get_region(both), "res://src/Assets/enemies/vault_baron_broken.png")

	var sheet := _load(PROPS)
	for prop_name: String in PROP_CELLS:
		var cell := sheet.get_region(PROP_CELLS[prop_name])
		_save(cell.get_region(_solid_rect(cell)), "res://src/Assets/boss/%s.png" % prop_name)
	quit()


func _load(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	image.convert(Image.FORMAT_RGBA8)
	return image


func _save(image: Image, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	image.save_png(ProjectSettings.globalize_path(path))
	print("wrote %s (%dx%d)" % [path, image.get_width(), image.get_height()])


## The bounding box of every pixel at least `SOLID_ALPHA` opaque.
func _solid_rect(image: Image) -> Rect2i:
	var lo := Vector2i(image.get_width(), image.get_height())
	var hi := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a >= SOLID_ALPHA:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)
