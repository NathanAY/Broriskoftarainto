extends Node2D
class_name PortalAura
## The living part of a world portal: glow motes spiralling in over the stone
## into the hole, plus two counter-rotating rune rings just outside it. Same
## family as `SpawnPortal` (glow pulled to a centre), but looping instead of
## one-shot. `surge()` and `flash()` are the entry animation's beats.
##
## Sized from the sibling `Sprite2D` (rule 1 in `docs/systems/effects.md`), and
## coloured through `color` times the portal's own `modulate`, so a tinted loop
## portal tints its aura for free.

const GLOW := preload("res://src/Assets/particles/particle_glow.png")
const SPARK := preload("res://src/Assets/particles/particle_spark.png")
## Used when there is no sibling sprite to measure.
const FALLBACK_RADIUS := 48.0
## Seconds a mote takes to spiral from the outer edge into the hole.
const SWIRL_LIFETIME := 1.2
## Where motes are born and where they land, as fractions of the ring's radius.
const SWIRL_OUTER := 1.35
const SWIRL_INNER := 0.05

@export var color := Color(1.0, 1.0, 1.0, 0.9)

## Ring radius in this node's local units. Read from the sprite in `_ready`.
var radius := FALLBACK_RADIUS
## 1 at rest; `surge()` drives it up so the rings and motes speed up and brighten.
var intensity := 1.0:
	set(value):
		intensity = value
		if _swirl:
			_swirl.speed_scale = value
var _age := 0.0
var _swirl: GPUParticles2D


func _ready() -> void:
	var sprite := get_parent().get_node_or_null("Sprite2D") as Sprite2D
	if sprite and sprite.texture:
		radius = sprite.texture.get_width() * sprite.scale.x * 0.5
	_swirl = _make_swirl()
	add_child(_swirl)


func _process(delta: float) -> void:
	_age += delta * intensity
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_age * 4.0)
	var strength := minf(intensity, 2.0)
	# Rim glow over the stone edge.
	draw_arc(Vector2.ZERO, radius * 0.97, 0.0, TAU, 64,
		Color(color, color.a * (0.18 + 0.12 * pulse) * strength), radius * 0.12, true)
	# Inner rune ring: three long dashes turning one way...
	for i in 3:
		var a := _age * 1.3 + i * TAU / 3.0
		draw_arc(Vector2.ZERO, radius * 1.12, a, a + 1.1, 20,
			Color(color, color.a * 0.75 * strength), 2.0, true)
	# ...outer ring: five short ones turning the other.
	for i in 5:
		var a := -_age * 0.8 + i * TAU / 5.0
		draw_arc(Vector2.ZERO, radius * 1.24, a, a + 0.5, 12,
			Color(color, color.a * 0.5 * strength), 1.5, true)


## Speeds the vortex up over `duration`: the portal winding up to swallow
## whoever entered it.
func surge(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "intensity", 3.0, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## A one-shot shockwave + spark burst at `global_pos` under `parent`, in world
## units. Runs while the tree is paused, because the shop pauses it on the same
## frame the flash starts.
static func flash(parent: Node, global_pos: Vector2, world_radius: float, tint: Color) -> Node2D:
	var node := PortalFlash.new()
	node.radius = world_radius
	node.color = tint
	parent.add_child(node)
	node.global_position = global_pos
	return node


## A short glowing trail for something flying into the portal. World-space
## (`local_coords = false`) so the motes stay behind as the carrier moves.
static func make_trail(tint: Color) -> GPUParticles2D:
	var trail := GPUParticles2D.new()
	trail.texture = GLOW
	trail.material = _additive()
	trail.amount = 48
	trail.lifetime = 0.35
	trail.local_coords = false
	var mat := ParticleProcessMaterial.new()
	mat.particle_flag_disable_z = true
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.25
	mat.scale_max = 0.4
	mat.color = tint
	mat.color_ramp = _fade_ramp()
	trail.process_material = mat
	return trail


func _make_swirl() -> GPUParticles2D:
	var swirl := GPUParticles2D.new()
	swirl.texture = GLOW
	swirl.material = _additive()
	swirl.amount = 40
	swirl.lifetime = SWIRL_LIFETIME
	swirl.preprocess = SWIRL_LIFETIME  # full from the first frame
	swirl.local_coords = true  # rule 2: follow the portal's scale and surge
	var mat := ParticleProcessMaterial.new()
	mat.particle_flag_disable_z = true
	mat.gravity = Vector3.ZERO
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0, 0, 1)
	mat.emission_ring_height = 0.0
	mat.emission_ring_radius = radius * SWIRL_OUTER
	mat.emission_ring_inner_radius = radius * (SWIRL_OUTER - 0.1)
	# Travel = 0.5 * accel * lifetime^2 would land a mote at SWIRL_INNER, but the
	# orbit adds tangential speed that fights the pull, so it is doubled.
	var pull := -4.0 * radius * (SWIRL_OUTER - SWIRL_INNER) / (SWIRL_LIFETIME * SWIRL_LIFETIME)
	mat.radial_accel_min = pull
	mat.radial_accel_max = pull
	mat.orbit_velocity_min = 0.2
	mat.orbit_velocity_max = 0.3
	mat.scale_min = 0.12
	mat.scale_max = 0.25
	mat.color = color
	mat.color_ramp = _fade_ramp()
	swirl.process_material = mat
	return swirl


static func _additive() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


## Fades in, holds, fades out, so no mote pops in or out at full brightness.
static func _fade_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.15, 0.85, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	return ramp


## The entry flash: a ring thrown outward, a bright core fading, and sparks.
class PortalFlash extends Node2D:
	const DURATION := 0.45
	var radius := 96.0
	var color := Color.WHITE
	var _age := 0.0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		z_index = 5  # over the player, who is the thing vanishing into it
		var sparks := GPUParticles2D.new()
		sparks.texture = SPARK
		sparks.material = PortalAura._additive()
		sparks.amount = 36
		sparks.lifetime = DURATION
		sparks.one_shot = true
		sparks.explosiveness = 1.0
		var mat := ParticleProcessMaterial.new()
		mat.particle_flag_disable_z = true
		mat.gravity = Vector3.ZERO
		mat.direction = Vector3(1, 0, 0)
		mat.spread = 180.0
		# Reach ~1.6 radii in DURATION, slowing as they go.
		mat.initial_velocity_min = radius * 2.5
		mat.initial_velocity_max = radius * 4.5
		mat.damping_min = radius * 4.0
		mat.damping_max = radius * 6.0
		mat.scale_min = 0.3
		mat.scale_max = 0.6
		mat.color = color
		mat.color_ramp = PortalAura._fade_ramp()
		sparks.process_material = mat
		add_child(sparks)
		sparks.emitting = true

	func _process(delta: float) -> void:
		_age += delta
		if _age >= DURATION:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := clampf(_age / DURATION, 0.0, 1.0)
		var fade := 1.0 - t
		draw_circle(Vector2.ZERO, radius * (0.9 - 0.6 * t), Color(1, 1, 1, 0.6 * fade * fade * fade))
		draw_arc(Vector2.ZERO, radius * (0.8 + 1.0 * t), 0.0, TAU, 64,
			Color(color, fade), 8.0 * fade + 1.0, true)
