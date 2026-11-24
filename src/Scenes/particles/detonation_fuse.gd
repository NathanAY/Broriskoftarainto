# res://src/Scenes/particles/detonation_fuse.gd
#
# The telegraph an `AreaBurstOnEnter` draws between its owner dying and the
# blast going off: the dead creature's own sprite swelling, squashing on a beat
# that speeds up, shaking and heating towards orange until it pops. Without it
# the corpse vanishes and, a second later, a blast appears out of nothing.
#
# It is drawn as a child of the burst, so it is freed with it when the blast
# goes off.
extends Node2D
class_name DetonationFuse

const HOT_COLOR := Color(1.0, 0.4, 0.1)
## Pulse rate at the start and at the end of the fuse, in Hz.
const BEEP_HZ_START := 2.0
const BEEP_HZ_END := 10.0
## How much bigger the sprite is drawn when the blast is due.
const SWELL := 0.45
## Squash-and-stretch amplitude on each pulse, at the end of the fuse.
const SQUASH := 0.12
## Shake amplitude at the end of the fuse, in pixels.
const SHAKE_PX := 5.0

## Seconds until the blast.
@export var duration: float = 1.0

## The dead creature's look, copied off its sprite by [method copy_sprite].
var texture: Texture2D = null
var sprite_scale := Vector2.ONE
var sprite_offset := Vector2.ZERO
var sprite_modulate := Color.WHITE

var _elapsed := 0.0


## Takes the sprite's texture, on-screen scale, flip and tint, so the fuse can
## draw the creature after its own node is gone. `origin` is the fuse's centre
## in global space.
func copy_sprite(sprite: Sprite2D, origin: Vector2) -> void:
	texture = sprite.texture
	sprite_scale = sprite.global_scale
	if sprite.flip_h:
		sprite_scale.x = -sprite_scale.x
	sprite_offset = sprite.global_position - origin
	# The elite tint lives on the container; the sprite's own modulate is the
	# hit flash, which is not worth carrying over.
	var holder := sprite.get_parent() as CanvasItem
	sprite_modulate = holder.modulate if holder != null else Color.WHITE


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


## 0 when the fuse is lit, 1 when the blast is due.
func progress() -> float:
	if duration <= 0.0:
		return 1.0
	return clampf(_elapsed / duration, 0.0, 1.0)


func _draw() -> void:
	if texture == null:
		return
	var p := progress()
	# The pulse rate rises linearly, so its phase is that rate's integral.
	var t := minf(_elapsed, duration)
	var phase := TAU * (BEEP_HZ_START * t + 0.5 * (BEEP_HZ_END - BEEP_HZ_START) * t * p)
	var beep := 0.5 + 0.5 * cos(phase)

	var swell := 1.0 + SWELL * p * p
	var squash := SQUASH * p * sin(phase)
	var draw_scale := sprite_scale * Vector2(swell + squash, swell - squash)
	var shake := Vector2(sin(_elapsed * 53.0), cos(_elapsed * 47.0)) * SHAKE_PX * p
	var tint := sprite_modulate * Color.WHITE.lerp(HOT_COLOR, 0.2 * p + 0.5 * p * beep)
	draw_set_transform(sprite_offset + shake, 0.0, draw_scale)
	draw_texture(texture, -texture.get_size() * 0.5, tint)
	draw_set_transform(Vector2.ZERO)
