extends Node2D

## Dev-only fixture: the explosion visual, rendered on its own so it can be
## eyeballed without playing up to the first bomb (see `run_scene_shot.bat`).
##
## The burst lasts under a second and the shot tool's own settle lands on its
## first frame, so this spawns a fresh row of blasts every
## [constant ROW_STRIDE_FRAMES] frames. Any shot then has a blast at every age
## from newborn to finished across it, and the `frames` argument to
## `run_scene_shot.bat` decides how much of the effect to advance before the
## capture:
##
##     run_scene_shot.bat res://test/tools/explosion_preview.tscn res://out.png 10
##
## Not part of the game: nothing loads this scene.

const EXPLOSION_SCENE: PackedScene = preload("res://src/Scenes/Explosion.tscn")

## Blast radii in **meters**, the unit `Explosion.radius` is authored in. A
## spread rather than one radius, because what is worth judging in a visual
## check is whether a small blast and a large one both read.
const SAMPLE_RADII := [0.21, 0.33, 0.6]

## Where the blasts sit, in pixels, relative to the viewport centre.
const SPREAD_X := [-340.0, 0.0, 340.0]
const BLAST_Y := 60.0

## How far apart the blasts in one row are spawned, in frames. Well under any
## layer's lifetime, so every row overlaps the last and the screen always holds
## blasts at a spread of ages rather than one age per row.
const ROW_STRIDE_FRAMES := 3

var _frames_until_next_row := 0


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	_frames_until_next_row -= 1
	if _frames_until_next_row > 0:
		return
	_frames_until_next_row = ROW_STRIDE_FRAMES
	_spawn_row()


func _spawn_row() -> void:
	var centre := get_viewport_rect().size * 0.5
	for index in SAMPLE_RADII.size():
		var explosion: Explosion = EXPLOSION_SCENE.instantiate()
		# `radius` and `damage` before `add_child`: `_ready` is what multiplies
		# the radius into pixels and spawns the burst from it, so a radius set
		# afterwards would draw the blast at its authored size while the
		# collision shape used the new one.
		explosion.radius = SAMPLE_RADII[index]
		# Nothing to hit in a preview, and a real blast would litter the shot
		# with damage numbers and flashes if anything were in range.
		explosion.damage = 0.0
		add_child(explosion)
		# Also after `add_child`: an unparented Node2D has no parent transform
		# to compose, so writing `global_position` first would store the world
		# position as a *local* one.
		explosion.global_position = centre + Vector2(SPREAD_X[index], BLAST_Y)