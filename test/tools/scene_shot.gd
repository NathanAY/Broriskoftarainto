extends Control

## Renders another scene to a PNG and quits, so a UI change can be eyeballed
## without a human opening the editor.
##
## Driven by `run_scene_shot.bat`:
##
##     run_scene_shot.bat <res://scene.tscn> [res://out.png] [frames]
##
## Both values arrive as *user* args (everything after `--`), because the plain
## argv belongs to Godot's own options.
##
## The target must stand on its own: it has to render with no gameplay set up
## (no `GlobalGameState`, no spawned character). For the character menu, point
## this at `test/tools/character_ui_preview.tscn`, which builds that setup
## itself.

## One frame to build the tree, one for the containers to size, one to draw.
const FRAMES_TO_SETTLE := 3

## Frames to wait past the settle, for a target that animates. Anything with a
## duration - a particle burst above all - is only meaningful partway through,
## and the settle alone lands on its first frame.
const DEFAULT_EXTRA_FRAMES := 0

var _target: String = ""
var _out_path: String = ""
var _extra_frames: int = DEFAULT_EXTRA_FRAMES


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		_fail("usage: run_scene_shot.bat <res://scene.tscn> [res://out.png] [frames]")
		return
	_target = args[0]
	_out_path = args[1] if args.size() > 1 else "res://scene_shot.png"
	# `int()` rather than a typed assignment: the argument arrives as a String,
	# and GDScript warns on the narrowing pass rather than doing it silently.
	_extra_frames = int(args[2]) if args.size() > 2 else DEFAULT_EXTRA_FRAMES

	if not ResourceLoader.exists(_target):
		_fail("no such scene: %s" % _target)
		return

	add_child(load(_target).instantiate())
	_shoot()


func _shoot() -> void:
	for i in FRAMES_TO_SETTLE + _extra_frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image: Image = get_viewport().get_texture().get_image()
	var err := image.save_png(_out_path)
	if err != OK:
		_fail("could not write %s (error %d)" % [_out_path, err])
		return
	print("scene_shot: wrote %s (%dx%d)" % [
		_out_path, image.get_width(), image.get_height()])
	get_tree().quit()


func _fail(message: String) -> void:
	push_error("scene_shot: " + message)
	get_tree().quit(1)
