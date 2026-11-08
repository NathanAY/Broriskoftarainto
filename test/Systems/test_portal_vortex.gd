class_name PortalVortexTest
extends GdUnitTestSuite

## The portals are a ring of stone with a transparent hole in the middle, and the
## gate surface inside that hole is `PortalVortex.tscn`: a shader on a quad.
##
## What these pin is what makes the effect appear at all:
##  - both portals use the shipped ring art, not the old tractor placeholder,
##  - the vortex draws *behind* the ring, so the stone hides its edge,
##  - its circular mask is sized from the hole measured out of the PNG, so a
##    later art swap cannot leave the disc too small (a visible gap) or so wide
##    that it spills past the ring's silhouette.

const LOOP_PORTAL: PackedScene = preload("res://src/Systems/LoopChoicePortal.tscn")
const SHOP_PORTAL: PackedScene = preload("res://src/Systems/ShopPortal.tscn")
const PORTAL_ART_PATH := "res://src/Assets/portal.png"
const VORTEX_SHADER_PATH := "res://src/Systems/portal_vortex.gdshader"


func _portal(scene: PackedScene) -> Area2D:
	var portal := scene.instantiate() as Area2D
	add_child(portal)
	return portal


func _sprite(portal: Node) -> Sprite2D:
	return portal.get_node_or_null("Sprite2D") as Sprite2D


func _vortex(portal: Node) -> MeshInstance2D:
	return portal.get_node_or_null("Vortex") as MeshInstance2D


## How far under the stone the disc edge has to sit, as a fraction of the
## texture width. Without a tuck the seam shows as a one-pixel line, which is
## exactly what the first version of this effect did at the top of the ring,
## where the hole is not centred on the canvas.
const MIN_TUCK := 0.02


## Geometry taken out of the art, as fractions of the texture width:
##  - `inner` is how far the transparent hole reaches from the canvas *centre*
##    along its farthest axis. This is what the mask has to cover, and it is
##    larger than the hole's own radius because the hole sits above the middle.
##  - `outer` is where the ring's silhouette ends along its nearest axis, so a
##    disc wider than this starts to emerge from behind the stone.
func _measure_gate(texture: Texture2D) -> Dictionary:
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	var width := image.get_width()
	var height := image.get_height()
	var centre := Vector2i(int(width / 2.0), int(height / 2.0))
	var inner_reach := 0
	var outer_reach := 1 << 30
	var directions: Array[Vector2i] = [
		Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	for direction in directions:
		var probe := centre
		while _inside(probe, width, height) \
				and image.get_pixel(probe.x, probe.y).a <= 0.5:
			probe += direction
		inner_reach = maxi(inner_reach, _axis_distance(probe - direction, centre))
		while _inside(probe, width, height) \
				and image.get_pixel(probe.x, probe.y).a > 0.5:
			probe += direction
		outer_reach = mini(outer_reach, _axis_distance(probe - direction, centre))
	return {
		"inner": float(inner_reach) / float(width),
		"outer": float(outer_reach) / float(width),
	}


func _inside(point: Vector2i, width: int, height: int) -> bool:
	return point.x >= 0 and point.y >= 0 and point.x < width and point.y < height


## Both probes run along one axis, so the two points differ on exactly one.
func _axis_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func test_both_portals_use_the_shipped_ring_art() -> void:
	for scene in [LOOP_PORTAL, SHOP_PORTAL]:
		var portal := _portal(scene)
		var sprite := _sprite(portal)
		assert_object(sprite).override_failure_message(
			"%s has no Sprite2D" % portal.name).is_not_null()
		assert_str(sprite.texture.resource_path).override_failure_message(
			"%s still shows the old placeholder art" % portal.name
		).is_equal(PORTAL_ART_PATH)
		portal.queue_free()


## Draw order is the whole trick: the quad is much wider than the visible gate,
## and the stone ring is what crops it. Behind the ring is the only correct spot.
func test_the_gate_surface_draws_behind_the_ring() -> void:
	for scene in [LOOP_PORTAL, SHOP_PORTAL]:
		var portal := _portal(scene)
		var vortex := _vortex(portal)
		var sprite := _sprite(portal)
		assert_object(vortex).override_failure_message(
			"%s has no vortex" % portal.name).is_not_null()
		assert_int(vortex.get_index()).override_failure_message(
			"the vortex must be drawn before the ring, or it paints over the stone"
		).is_less(sprite.get_index())
		portal.queue_free()


func test_the_vortex_uses_the_portal_shader() -> void:
	var portal := _portal(LOOP_PORTAL)
	var material := _vortex(portal).material as ShaderMaterial
	assert_object(material).override_failure_message(
		"the vortex has no ShaderMaterial").is_not_null()
	assert_str(material.shader.resource_path).is_equal(VORTEX_SHADER_PATH)
	portal.queue_free()


## The quad has to cover the sprite's whole *drawn rect* for the shader's UV-space
## mask to land where the hole is. The art is authored at its own size and the
## scene scales the sprite down, so both the canvas and the scale are read from
## the sprite: a vortex left at the art's raw size, or at scale 1, would sit the
## mask in the wrong place.
func test_the_vortex_covers_the_sprite_drawn_rect() -> void:
	for scene in [LOOP_PORTAL, SHOP_PORTAL]:
		var portal := _portal(scene)
		var sprite := _sprite(portal)
		var vortex := _vortex(portal)
		var quad := vortex.mesh as QuadMesh
		assert_object(quad).override_failure_message(
			"the vortex is not a quad").is_not_null()
		var drawn := quad.size * vortex.scale
		var art := sprite.texture.get_size() * sprite.scale
		assert_vector(drawn).override_failure_message(
			"the vortex does not cover the rect the art is drawn in, so the mask "
			+ "no longer lines up with the hole").is_equal_approx(
				art, Vector2(0.01, 0.01))
		portal.queue_free()


## The mask has to reach the hole's farthest point *plus* a tuck under the stone,
## and stop before the ring's silhouette. The hole in the shipped art is not
## centred on the canvas — it sits above the middle — which is why a mask sized
## to the hole's own radius left a one-pixel line at the top of the ring.
func test_the_mask_covers_the_offset_hole_and_stays_behind_the_stone() -> void:
	for scene in [LOOP_PORTAL, SHOP_PORTAL]:
		var portal := _portal(scene)
		var material := _vortex(portal).material as ShaderMaterial
		var hole_radius: float = material.get_shader_parameter("hole_radius")
		var gate := _measure_gate(_sprite(portal).texture)
		assert_float(hole_radius).override_failure_message(
			"hole_radius does not tuck under the stone at the far edge of the "
			+ "offset hole, so a sliver of floor shows through").is_greater_equal(
				gate["inner"] + MIN_TUCK)
		# The stone is the only thing hiding the disc's edge, so the disc may tuck
		# under it but not extend past it.
		assert_float(hole_radius).override_failure_message(
			"hole_radius is so wide the disc emerges from behind the stone"
		).is_less_equal(gate["outer"] - MIN_TUCK)
		portal.queue_free()


## A scene instance shares its sub-resources with every other instance, so two
## portals spawned in one frame would otherwise both write the same QuadMesh.
func test_each_portal_gets_its_own_quad() -> void:
	var first := _portal(LOOP_PORTAL)
	var second := _portal(LOOP_PORTAL)
	assert_object(_vortex(first).mesh).override_failure_message(
		"two portals share one QuadMesh, so sizing one retargets the other"
	).is_not_same(_vortex(second).mesh)
	first.queue_free()
	second.queue_free()


## The ring art is authored at 500 and drawn at 144, so it is minified every
## frame — harder as the camera zooms out. Without mipmaps it aliases and
## shimmers, and a plain linear filter would not sample mipmaps even if the PNG
## imported with them, so both halves are pinned.
func test_the_ring_art_is_filtered_with_mipmaps() -> void:
	for scene in [LOOP_PORTAL, SHOP_PORTAL]:
		var portal := _portal(scene)
		assert_int(_sprite(portal).texture_filter).override_failure_message(
			"the portal art is minified, so its sprite needs mipmapped filtering"
		).is_equal(CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
		portal.queue_free()

	var config := ConfigFile.new()
	assert_int(config.load("res://src/Assets/portal.png.import")).is_equal(OK)
	assert_bool(config.get_value("params", "mipmaps/generate", false)).override_failure_message(
		"portal.png imports without mipmaps, so the filter above has nothing to sample"
	).is_true()
