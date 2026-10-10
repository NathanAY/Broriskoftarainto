extends SceneTree

## Dev-only tool: renders the soft, ink-free particle sprites the explosion
## visual needs into `src/Assets/particles/`.
##
## Run it from the repo root:
##
##     godot --headless --path . -s res://test/tools/make_soft_particles.gd
##
## It exists because the shipped particle art cannot do this job. Every one of
## `particle_1.png` .. `particle_27.png` is drawn in the project's Borderlands
## style, and that style's load-bearing feature is a heavy inked black outline -
## measured at 53-72% near-black pixels across the set. A particle emitter tints
## its texture, and a tint cannot separate the ink from the fill: multiply the
## black and the white together and both come out the same dark colour. A fire
## layer built on those textures renders as a black blob no matter what the
## gradient says, and switching the layer to additive blending makes it worse,
## because additive *adds* the outline instead of discarding it.
##
## So the explosion's sprites are generated here instead: pure luminance falloff
## on a transparent background, no ink, which is what a tintable particle has
## to be. Regenerate rather than hand-edit - the numbers below are the design.

const OUT_DIR := "res://src/Assets/particles/"

## Canvas size for every sprite, matching the shipped particle art so they can be
## swapped in without touching a `scale_min` / `scale_max`.
const SIZE := 64


func _init() -> void:
	# A soft round glow: bright core falling off to nothing. The workhorse - it
	# is the fireball, the flash, and the spark when tinted.
	_save("particle_glow.png", _radial_falloff(2.2, 0.0, 1.0, 0.0, false))
	# A smoke puff: the same falloff, but lumpy and hollowed, so overlapping puffs
	# read as billowing rather than as a stack of identical circles. `edge_falloff`
	# above zero lifts the rim, which is what stops a cluster of them looking like
	# one smooth balloon.
	_save("particle_smoke.png", _radial_falloff(1.6, 0.22, 0.82, 0.16, true))
	# A spark: a tight bright dot with a faint wide halo. Reads as a hot fragment
	# at speed rather than as a blob.
	_save("particle_spark.png", _spark())
	# A shard: a small soft lozenge, stretched by the emitter into the debris that
	# rides the shockwave out to the blast edge.
	_save("particle_shard.png", _shard())
	print("make_soft_particles: wrote 4 sprites to ", OUT_DIR)
	quit()


func _save(file_name: String, image: Image) -> void:
	var err := image.save_png(OUT_DIR + file_name)
	if err != OK:
		printerr("make_soft_particles: could not write ", file_name, " (", err, ")")


## A radial luminance falloff, optionally lumpy and hollowed at the rim.
##
## `center_falloff` shapes the profile: higher is a tighter, brighter core, lower
## is a broad even haze. `edge_falloff` is the luminance the rim is lifted *to*,
## which is what gives smoke its billowed interior instead of a hard disc edge.
## `noise` is the amplitude of a fixed, seeded value-noise wobble on the radius -
## deterministic on purpose, so regenerating gives byte-identical output and a
## sprite never shifts under a committed scene.
## `soft_alpha` picks between two alpha profiles, and the difference matters more
## than it looks. With it off, alpha is flat across the inner disc and only ramps
## near the rim - correct for a sprite drawn additively, where brightness carries
## the shape and a hard alpha edge is invisible. With it on, alpha follows the
## same falloff as luminance, so density decays smoothly all the way out. That is
## what the smoke needs: a flat-alpha disc that is then tinted dark by its
## gradient renders as an opaque dark ball, because the noise in the radius turns
## an opaque region into a lumpy opaque silhouette rather than a soft one.
func _radial_falloff(center_falloff: float, edge_falloff: float, core: float, noise: float, soft_alpha: bool) -> Image:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261010
	# A small fixed lattice the radius is sampled through, so the lumpiness has
	# structure rather than being per-pixel static.
	var offsets: Array[Vector2] = []
	for i in 12:
		offsets.append(Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)))
	var half := float(SIZE) * 0.5
	for y in SIZE:
		for x in SIZE:
			var uv := Vector2(float(x) - half, float(y) - half) / half
			var distance := uv.length()
			if distance > 1.0:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var wobble := 0.0
			if noise > 0.0:
				wobble = _value_noise(Vector2(uv) * 2.2, offsets) * noise
			var shaped := clampf(distance + wobble, 0.0, 1.0)
			# Smoothstep the profile so the edge reaches zero smoothly; a linear
			# ramp leaves a visible ring where the sprite meets transparency.
			var falloff := pow(1.0 - shaped, center_falloff)
			var value := lerpf(edge_falloff, core, falloff)
			# Alpha carrying a hard 1.0 across the inner disc would leave an opaque
			# shape ending on a visible circular edge, so it always falls to zero
			# *inside* the sprite's radius.
			var alpha := smoothstep(1.0, 0.55, shaped)
			if soft_alpha:
				alpha *= falloff
			image.set_pixel(x, y, Color(value, value, value, alpha))
	return image


## A bright core plus a wide faint halo. Two profiles summed: a tight `pow` dot
## over a broad one, which is what makes the centre read as hot.
func _spark() -> Image:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var half := float(SIZE) * 0.5
	for y in SIZE:
		for x in SIZE:
			var uv := Vector2(float(x) - half, float(y) - half) / half
			var distance := uv.length()
			if distance > 1.0:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			# The core is a separate, much tighter profile than the halo: one
			# `pow` cannot be both a hot dot and a wide haze.
			var core := pow(clampf(1.0 - distance / 0.22, 0.0, 1.0), 1.5)
			var halo := pow(clampf(1.0 - distance, 0.0, 1.0), 3.0) * 0.3
			var value := clampf(core + halo, 0.0, 1.0)
			image.set_pixel(x, y, Color(value, value, value, smoothstep(1.0, 0.5, distance)))
	return image


## A soft-edged lozenge: a circle falloff squeezed on one axis.
##
## Drawn pointing along +X so an emitter's `angle_min` / `angle_max` can aim it.
## It is symmetric enough that rotating it either way reads fine, which matters
## because the shockwave throws these in every direction at once.
func _shard() -> Image:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var half := float(SIZE) * 0.5
	for y in SIZE:
		for x in SIZE:
			var uv := Vector2(float(x) - half, float(y) - half) / half
			# Stretch along X by inverse-squashing the coordinate, so the falloff
			# maths below is unchanged and only the silhouette differs.
			var squashed := Vector2(uv.x * 1.9, uv.y * 0.85)
			var distance := squashed.length()
			if distance > 1.0:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var value := pow(clampf(1.0 - distance, 0.0, 1.0), 1.7)
			image.set_pixel(x, y, Color(value, value, value, smoothstep(1.0, 0.4, distance)))
	return image


## Smoothly interpolated value noise over a fixed offset lattice, so the wobble
## in [method _radial_falloff] has shape at the sprite's scale instead of being
## per-pixel hash. Returns roughly -1..1.
func _value_noise(p: Vector2, offsets: Array[Vector2]) -> float:
	var cell := 4.0
	var fx := p / cell
	var ix := floori(fx.x)
	var iy := floori(fx.y)
	var tx := fx.x - float(ix)
	var ty := fx.y - float(iy)
	# Smoothstep the interpolation weights, or the lattice shows through as
	# visible square facets in the smoke.
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := _lattice(offsets, ix, iy)
	var b := _lattice(offsets, ix + 1, iy)
	var c := _lattice(offsets, ix, iy + 1)
	var d := _lattice(offsets, ix + 1, iy + 1)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


## One lattice sample, wrapped so the sprite tiles seamlessly in the noise.
func _lattice(offsets: Array[Vector2], ix: int, iy: int) -> float:
	var count := offsets.size()
	var index := (posmod(ix, count) * 7 + posmod(iy, count) * 13) % count
	return offsets[index].x * 0.6 + offsets[index].y * 0.4