# A blinker: it chases like the basic enemy, but every `blink_interval` it
# teleports to a random point within `blink_radius` of its target.
#
# The teleport is a reposition rather than a movement: velocity is cleared for
# that frame so the body does not carry its old heading into the new spot, and
# the visual is faded back in on the `Node2D` container so `HitFlashManager`,
# which tweens the sprite's own modulate, cannot fight the fade.
extends MovementBehaviour
class_name BlinkMovementBehaviour

## Seconds between blinks.
@export var blink_interval: float = 3.0

## How far from the target the blinker may reappear, in pixels. It is smaller
## than the spawner's ring around the player, so a blink is always a step
## closer rather than a reset.
@export var blink_radius: float = 220.0

## Closest the blinker may reappear to the target, so it does not land on top
## of the player.
@export var min_blink_distance: float = 60.0

## Seconds the reappearance fade lasts.
@export var fade_time: float = 0.2

var _time_since_blink: float = 0.0


func process_movement(creature_self: CharacterBody2D, delta: float) -> void:
	var node = creature_self.target
	if not node:
		return
	_time_since_blink += delta
	if blink_interval > 0.0 and _time_since_blink >= blink_interval:
		_time_since_blink = 0.0
		_blink(creature_self, node)
		return
	_chase(creature_self, node)


func _chase(creature_self: CharacterBody2D, node: Node) -> void:
	var to_target: Vector2 = node.global_position - creature_self.global_position
	if to_target.length() <= 1.0:
		creature_self.velocity = Vector2.ZERO
		creature_self.anim_player.play("idle")
		return
	var direction := to_target.normalized()
	creature_self.velocity = direction * creature_self.stats.get_movement_speed_px()
	creature_self.anim_player.play("move")
	creature_self.sprite.flip_h = direction.x < 0


## Moves the body to a random point in a ring around the target.
func _blink(creature_self: CharacterBody2D, node: Node) -> void:
	var angle := randf_range(0.0, TAU)
	var distance := randf_range(min_blink_distance, maxf(min_blink_distance, blink_radius))
	creature_self.global_position = node.global_position + Vector2(cos(angle), sin(angle)) * distance
	creature_self.velocity = Vector2.ZERO
	creature_self.anim_player.play("idle")
	_fade_in(creature_self)


## Fades the whole visual back in after the teleport.
func _fade_in(creature_self: CharacterBody2D) -> void:
	var visual := creature_self.get_node_or_null("Node2D") as CanvasItem
	if visual == null:
		return
	visual.modulate.a = 0.0
	var tween := creature_self.create_tween()
	tween.tween_property(visual, "modulate:a", 1.0, fade_time)
