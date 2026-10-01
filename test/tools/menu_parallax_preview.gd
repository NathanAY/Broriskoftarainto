extends Control

## Visual check for the main menu's three parallax layers.
##
## The menu itself cannot show all three at once. Every layer is full-bleed, so
## the one in front hides the ones behind it - correct behaviour for the finished
## art, where the near layers are transparent PNGs with sparse content, and
## useless for checking the rig, where each is a flat rectangle. Step 1 of
## docs/archive/main_menu_parallax_background.md asks for the cover-fit to be
## verified on flat colours, and this is what makes that possible.
##
## So each layer gets its own full-bleed cell, pinned to the worst case: the
## extreme of its travel, which is where a gap at an edge first appears. Cells
## are a tall aspect, which is the harder direction for a cover fit - it has to
## scale on height and crop the width instead of the other way round.
##
## Run with:
##
##     .\run_scene_shot.bat res://test/tools/menu_parallax_preview.tscn res://parallax.png
##
## The file is deliberately not named `test_*.gd`, so the gdUnit and GUT runners
## skip it.

## One entry per layer, mirroring the rig in src/Scenes/menu/Main.tscn. Kept as
## literals rather than read from the scene so this renders standalone, without a
## Main to instantiate.
const LAYERS := [
	{"name": "Far", "travel": 24.0, "sway_period": 14.0, "sway_phase": 0.0,
		"mouse_travel": 8.0, "texture": "res://src/Assets/menu/parallax_far.png",
		"push_right": true},
	{"name": "Mid", "travel": 48.0, "sway_period": 10.0, "sway_phase": 0.35,
		"mouse_travel": 14.0, "texture": "res://src/Assets/menu/parallax_mid.png",
		"push_right": false},
	{"name": "Near", "travel": 84.0, "sway_period": 7.0, "sway_phase": 0.7,
		"mouse_travel": 22.0, "texture": "res://src/Assets/menu/parallax_near.png",
		"push_right": true},
]

const CELL_BG := Color(0.078431, 0.082353, 0.101961, 1.0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 8)
	add_child(row)

	for spec in LAYERS:
		row.add_child(_make_cell(spec))


func _make_cell(spec: Dictionary) -> Control:
	var cell := PanelContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Essential, not cosmetic. A cover-fitted layer is deliberately larger than
	# its cell, and without clipping the overflow spills across the window and
	# paints over the neighbouring cells - which is the exact occlusion this
	# preview exists to avoid. Clipped, each cell shows one layer edge to edge,
	# so any gap exposes the cell background.
	cell.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = CELL_BG
	style.set_border_width_all(2)
	style.border_color = Color(0.541176, 0.729412, 0.909804, 1.0)
	cell.add_theme_stylebox_override("panel", style)

	# PanelContainer hands its child the full inner rect, which is what makes the
	# layer fit to the cell rather than to the window.
	var layer := MenuParallaxLayer.new()
	layer.name = "%sLayer" % spec["name"]
	layer.travel = spec["travel"]
	layer.sway_period = spec["sway_period"]
	layer.sway_phase = spec["sway_phase"]
	layer.mouse_travel = spec["mouse_travel"]
	cell.add_child(layer)

	var art := TextureRect.new()
	art.name = MenuParallaxLayer.ART_PATH
	art.texture = load(spec["texture"])
	# The layer sizes this rect itself, so the mode has to be plain scale or the
	# texture would be letterboxed inside a rect the cover-fit already sized.
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	layer.add_child(art)

	# Worst case: the layer pushed to the very end of its travel, in alternating
	# directions so one render shows the left-edge and the right-edge risk.
	var extreme: float = layer.margin
	layer.set_shift(extreme if spec["push_right"] else -extreme)

	var caption := Label.new()
	caption.text = "%s  travel %d  margin %d  %s" % [
		spec["name"],
		int(layer.travel),
		int(layer.margin),
		"+" if spec["push_right"] else "-",
	]
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", Color(0.909804, 0.925490, 0.968627, 1.0))
	return _with_caption(cell, caption)


## Stacks the caption under the cell, keeping the layer's rect full-bleed within
## the cell itself.
func _with_caption(cell: Control, caption: Control) -> Control:
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 4)
	stack.add_child(cell)
	stack.add_child(caption)
	return stack