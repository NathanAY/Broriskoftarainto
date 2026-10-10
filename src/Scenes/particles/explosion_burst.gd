# res://src/Scenes/particles/explosion_burst.gd
#
# The one-shot visual an `Explosion` plays when it goes off.
#
# `Explosion` used to answer that with `_draw()`: one flat, half-transparent
# white circle at the blast radius, fading over the damage window. It read as a
# placeholder rather than as a blast - no shape, no direction, no aftermath.
# This scene is the replacement: five GPU particle layers authored against a
# single reference blast and scaled as one unit, so the whole effect grows and
# shrinks with the damage radius instead of only the collision shape doing so.
#
# The layers, in draw order:
#
# | Layer       | What it is                                    |
# | ---         | ---                                           |
# | `Shockwave` | a ring of shards thrown outward to the edge   |
# | `Smoke`     | dark puffs that linger after the light is gone |
# | `Fireball`  | the hot cloud that blooms and cools            |
# | `Sparks`    | small hot fragments flung out on ballistic arcs|
# | `Flash`     | the brief white core, on top of everything     |
#
# `Smoke` sits under `Fireball` rather than above it: it is the only layer that
# blends normally instead of additively, so drawn on top it punches a flat grey
# hole through the middle of the fire.
#
# `radius` is [member Explosion.get_radius_px] - the same number the collision
# shape takes - so the wavefront lands on the edge of the area that was
# actually damaged.
extends Node2D
class_name ExplosionBurst

## Blast radius in **pixels** that the scene's particles are authored against.
##
## Every emission radius, velocity and particle size in the scene assumes a
## blast this wide, and [method _ready] scales the whole node by
## `radius / BASE_RADIUS`. Scaling the node rather than each material is what
## makes the visual proportional to the damage in one step - the particle
## *travel* scales too, because particles are emitted in this node's local
## space and drawn through its transform.
##
## That last clause is load-bearing, and it is why every layer in the scene sets
## `local_coords = true`. The default is `false`, which simulates particles in
## world space and makes the emitter ignore its own parent's transform entirely
## - so scaling this node would move the node and change nothing about the
## effect, and a doubled blast radius would draw at the authored size.
const BASE_RADIUS := 96.0

## The blast radius in pixels, from `Explosion.get_radius_px()`. Set before
## `add_child`, because `_ready` is what applies it.
@export var radius: float = BASE_RADIUS


func _ready() -> void:
	scale = Vector2.ONE * maxf(radius, 0.0) / BASE_RADIUS
	for child in get_children():
		var emitter := child as GPUParticles2D
		if emitter != null:
			_emit(emitter)


## Restarts a one-shot emitter, so two explosions spawned in the same frame both
## play instead of the second being swallowed by the first. The emitters ship
## with `emitting = false` and are started here for the same reason
## `AreaDamageBurst` does it: `one_shot` emitters that were already emitting
## when the node entered the tree would burst on their first rendered frame,
## which is one frame of extra latency at the least.
func _emit(emitter: GPUParticles2D) -> void:
	emitter.emitting = false
	emitter.emitting = true


## The longest any of the layers lives, in seconds.
##
## The parent uses this as a floor for how long it stays alive, so retuning a
## layer's `lifetime` in the editor cannot silently leave the parent freeing
## itself mid-effect and cutting the tail off the smoke.
func get_longest_lifetime() -> float:
	var longest := 0.0
	for child in get_children():
		var emitter := child as GPUParticles2D
		if emitter != null:
			longest = maxf(longest, emitter.lifetime)
	return longest