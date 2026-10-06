# res://src/Scenes/particles/area_damage_burst.gd
#
# The one-shot visual that an `AreaWeapon` spawns on each firing tick.
#
# `AreaWeapon` deals its damage to every target the selector returns, so there
# is no single impact point to hang a sprite on - what the player needs to see
# is *how far* the damage reached. This draws that radius instead: a wavefront
# of shards thrown outward that arrives at the aura's edge exactly as it dies,
# plus a short flash where the pulse was born.
#
# `radius` is set from the weapon's own `radius` (half its `weapon_range`) rather
# than baked into the scene, so the visual cannot drift away from the number the
# `AllTargetsInRangeSelector` actually measures against.
extends Node2D
class_name AreaDamageBurst

## Where along the outward leg of the wavefront the shards start, as a fraction
## of `radius`. Below 1 so they travel outward as they fade; at 1 they would sit
## on the damage edge from the first frame, which reads as a static ring rather
## than as a pulse.
const START_FRACTION := 0.55

## Distance from the centre the wavefront ends on, matching the weapon's
## `AreaWeapon.radius`.
@export var radius: float = 200.0

## Tint for both layers. The shipped weapon is toxic, hence the green; the
## gradient in the scene does the fade to transparent.
@export var tint: Color = Color(0.55, 1.0, 0.45, 1.0)

@onready var _rim: GPUParticles2D = get_node_or_null("Rim") as GPUParticles2D
@onready var _flash: GPUParticles2D = get_node_or_null("Flash") as GPUParticles2D


func _ready() -> void:
	_retarget_rim(_rim, radius)
	_tint(_flash)
	_emit(_rim)
	_emit(_flash)
	# `finished` fires only once the last live particle has died, which is the
	# point at which this node is pure garbage. Same self-cleanup the hit
	# particles use in `particle_effect_manager.gd`.
	if _rim and not _rim.finished.is_connected(queue_free):
		_rim.finished.connect(queue_free)


## Aims the rim shards so the wavefront ends on `target_radius`.
##
## Both the ring it is emitted on and the speed follow the radius, rather than
## only the ring: a longer aura has to take longer to cross, or the shards reach
## its edge while still at full brightness and then keep going, drawing damage
## well past what was hit. Shards emitted at `START_FRACTION` and travelling the
## remaining distance over one lifetime arrive exactly on the edge as they fade.
##
## The material is duplicated per instance first. A `PackedScene`'s
## sub-resources belong to the scene, not to the instance, so writing the shared
## `process_material` would leave every later burst - and the scene on disk the
## next time it is opened - carrying this weapon's range.
func _retarget_rim(emitter: GPUParticles2D, target_radius: float) -> void:
	if emitter == null or emitter.process_material == null:
		return
	var ring := emitter.process_material.duplicate() as ParticleProcessMaterial
	emitter.process_material = ring
	_tint(emitter)
	if ring.emission_shape != ParticleProcessMaterial.EMISSION_SHAPE_RING:
		return
	var inner := target_radius * START_FRACTION
	ring.emission_ring_inner_radius = inner * 0.92
	ring.emission_ring_radius = inner
	var authored_speed := ring.initial_velocity_max
	if authored_speed > 0.0:
		var speed := (target_radius - inner) / maxf(emitter.lifetime, 0.01)
		ring.initial_velocity_max = speed
		ring.initial_velocity_min = speed * (ring.initial_velocity_min / authored_speed)


func _tint(emitter: GPUParticles2D) -> void:
	if emitter != null and emitter.process_material != null:
		(emitter.process_material as ParticleProcessMaterial).color = tint


## Restarts a one-shot emitter, so two bursts spawned in the same frame both
## play instead of the second one being swallowed by the first.
func _emit(emitter: GPUParticles2D) -> void:
	if emitter == null:
		return
	emitter.emitting = false
	emitter.emitting = true