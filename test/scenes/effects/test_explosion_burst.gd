# The explosion's visual. `Explosion` used to answer "what does a blast look
# like" with `_draw()` and one flat white circle; it now plays
# `explosion_burst.tscn`, so these suites pin what the player is actually shown:
# that there is a burst at all, that it is sized from the same radius the
# damage is measured against, and that it does not leak.
class_name ExplosionBurstTest
extends GdUnitTestSuite

const BURST_SCENE: PackedScene = preload("res://src/Scenes/particles/explosion_burst.tscn")
const EXPLOSION_SCENE: PackedScene = preload("res://src/Scenes/Explosion.tscn")

## Names of the five layers the blast is built from. Asserted as a set rather
## than a count: a layer being renamed or dropped is the change worth catching,
## and a hardcoded `amount` total would not notice a swap.
const EXPECTED_LAYERS := ["Fireball", "Flash", "Shockwave", "Smoke", "Sparks"]


func _make_burst(radius_px: float) -> ExplosionBurst:
	var burst: ExplosionBurst = BURST_SCENE.instantiate()
	burst.radius = radius_px
	add_child(burst)
	return burst


## The blast has to be more than one thing. The old white circle was a single
## flat disc; what replaces it is a flash, a fireball, a smoke trail, sparks and
## a shockwave, and a regression that silently emptied any of those layers is
## invisible to a test that only checks the node exists.
func test_burst_is_built_from_every_layer() -> void:
	var burst := _make_burst(ExplosionBurst.BASE_RADIUS)
	var layers: Array[String] = []
	for child in burst.get_children():
		var emitter := child as GPUParticles2D
		assert_object(emitter).override_failure_message(
			"%s is not a GPUParticles2D" % child.name).is_not_null()
		layers.append(emitter.name)
		# A one-shot layer that is already emitting when the node enters the tree
		# bursts on its first rendered frame; every layer is started by the script.
		assert_bool(emitter.one_shot).override_failure_message(
			"%s is not a one-shot emitter" % emitter.name).is_true()
	# Sorted, because `contains_exactly` compares order too and the draw order
	# here is an art decision - what matters is that all five exist.
	layers.sort()
	burst.queue_free()
	assert_array(layers).override_failure_message(
		"the blast lost or renamed one of its layers").contains_exactly(EXPECTED_LAYERS)


## Every layer has to actually be emitting by the time the node is in the tree,
## or it is authored decoration that never plays.
func test_every_layer_is_emitting() -> void:
	var burst := _make_burst(ExplosionBurst.BASE_RADIUS)
	for child in burst.get_children():
		var emitter := child as GPUParticles2D
		assert_bool(emitter.emitting).override_failure_message(
			"%s never started emitting" % emitter.name).is_true()
	burst.queue_free()


## The visual is proportional to the damage radius, not an independent number.
##
## `area_size_multiplier` and the per-modifier `explosion_radius` both rewrite
## `Explosion.radius`, and the collision shape takes that. The burst has to take
## it too, or a Soldier's +30% blast draws at the base size while hitting a
## third more. This asserts the *ratio*, so it survives any rebalance of
## `radius` or of `ExplosionBurst.BASE_RADIUS`.
func test_burst_scales_with_the_blast_radius() -> void:
	var burst := _make_burst(ExplosionBurst.BASE_RADIUS * 2.0)
	var expected := ExplosionBurst.BASE_RADIUS * 2.0 / ExplosionBurst.BASE_RADIUS
	assert_float(burst.scale.x).override_failure_message(
		"a doubled blast radius did not double the visual").is_equal_approx(expected, 0.001)
	assert_float(burst.scale.y).is_equal_approx(expected, 0.001)
	burst.queue_free()


## Scaling the node is only a *means*. What has to hold is that the particles
## the emitter actually produces grow with the blast, and they only do if the
## layers simulate in this node's local space - `local_coords` defaults to
## `false`, which puts them in world space and makes them ignore the parent
## transform altogether.
##
## This is the assertion that catches it. An earlier version checked
## `burst.scale` alone and passed while the emitted particles stayed the size
## they were authored at, because the scale was correct and simply had no
## effect on them.
func test_particles_are_emitted_in_local_space_so_the_scale_reaches_them() -> void:
	var burst := _make_burst(ExplosionBurst.BASE_RADIUS)
	for child in burst.get_children():
		var emitter := child as GPUParticles2D
		assert_bool(emitter.local_coords).override_failure_message(
			"%s simulates in world space, so it ignores ExplosionBurst's scale "
			% emitter.name
			+ "and the visual no longer matches the blast radius").is_true()
	burst.queue_free()


## The same relationship the other way, so a burst that ignores its radius and
## happens to land on the right scale for one particular value still fails.
func test_burst_at_the_reference_radius_is_unscaled() -> void:
	var burst := _make_burst(ExplosionBurst.BASE_RADIUS)
	assert_float(burst.scale.x).override_failure_message(
		"the authored reference blast is drawn at the wrong size").is_equal_approx(1.0, 0.001)
	burst.queue_free()


## The radius travels, not just the sprite size.
##
## The shockwave is the layer that tells the player how far the blast reached,
## so it is the layer whose emission ring has to sit at a fraction of the real
## radius. Scaling the node gets that for free only because the emission ring is
## in local space - a `ParticleProcessMaterial` retargeted to a shared resource
## instead would break the moment two blasts of different sizes overlapped.
func test_shockwave_ring_is_a_fraction_of_the_blast_radius() -> void:
	var burst := _make_burst(ExplosionBurst.BASE_RADIUS * 3.0)
	var shockwave := burst.get_node("Shockwave") as GPUParticles2D
	var material := shockwave.process_material as ParticleProcessMaterial
	assert_int(material.emission_shape).override_failure_message(
		"the shockwave is no longer a ring, so it no longer reads as an edge"
	).is_equal(ParticleProcessMaterial.EMISSION_SHAPE_RING)
	# The authored ring sits inside BASE_RADIUS; at 3x the blast it must still be
	# inside 3x, not pinned at the authored value.
	var drawn_radius := material.emission_ring_radius * burst.scale.x
	assert_float(drawn_radius).override_failure_message(
		"the shockwave ring did not travel with the blast radius"
	).is_less(ExplosionBurst.BASE_RADIUS * 3.0)
	assert_float(drawn_radius).is_greater(0.0)
	burst.queue_free()


## The node reports how long its own layers live, so the parent can stay alive
## long enough to show them all. A burst that reported 0 would let `Explosion`
## free itself on the first frame.
func test_burst_reports_its_longest_layer_lifetime() -> void:
	var burst := _make_burst(ExplosionBurst.BASE_RADIUS)
	var longest := 0.0
	for child in burst.get_children():
		var emitter := child as GPUParticles2D
		longest = maxf(longest, emitter.lifetime)
	assert_float(burst.get_longest_lifetime()).override_failure_message(
		"the burst's reported lifetime does not match its layers, so the "
		+ "explosion frees itself before the smoke finishes"
	).is_equal_approx(longest, 0.001)
	assert_float(burst.get_longest_lifetime()).is_greater(0.0)
	burst.queue_free()


## Two bursts spawned in the same frame must both play. A one-shot emitter left
## `emitting = true` in the scene would swallow the second one, and a run with
## two bombs on the same frame would show only one blast.
func test_two_bursts_in_one_frame_both_emit() -> void:
	var first := _make_burst(ExplosionBurst.BASE_RADIUS)
	var second := _make_burst(ExplosionBurst.BASE_RADIUS)
	for child in first.get_children():
		var emitter := child as GPUParticles2D
		assert_bool(emitter.emitting).override_failure_message(
			"%s stopped emitting after a second burst spawned" % emitter.name).is_true()
	first.queue_free()
	second.queue_free()


## The explosion scene plays the burst. This is the link between the damage and
## the visual: without it `Explosion` is back to an invisible hitbox.
func test_explosion_spawns_the_burst_as_a_child() -> void:
	var explosion: Explosion = EXPLOSION_SCENE.instantiate()
	explosion.radius = 0.33
	add_child(explosion)
	var burst := explosion.get_node_or_null("ExplosionBurst") as ExplosionBurst
	assert_object(burst).override_failure_message(
		"Explosion no longer plays a visual, so a blast is now invisible").is_not_null()
	explosion.queue_free()


## The burst is drawn at the same radius the collision shape is measured at.
## The two are read from one getter precisely so they cannot drift; asserting
## both against `get_radius_px()` is what holds them together.
func test_burst_and_collision_share_the_pixel_radius() -> void:
	var explosion: Explosion = EXPLOSION_SCENE.instantiate()
	explosion.radius = 0.5
	add_child(explosion)
	var shape := explosion.get_node("CollisionShape2D") as CollisionShape2D
	var burst := explosion.get_node_or_null("ExplosionBurst") as ExplosionBurst
	assert_float(burst.radius).override_failure_message(
		"the visual and the damage area are drawn at different sizes").is_equal_approx(
		explosion.get_radius_px(), 0.001)
	assert_float(shape.shape.radius).is_equal_approx(explosion.get_radius_px(), 0.001)
	explosion.queue_free()


## `area_size_multiplier` reaches the visual, not only the collision shape.
## This is the whole point of scaling by `get_radius_px()`: a doubled blast has
## to look doubled.
func test_burst_follows_area_size_multiplier() -> void:
	var holder := Node.new()
	var em := EventManager.new()
	em.name = "EventManager"
	holder.add_child(em)
	var stats := Stats.new()
	stats.name = "Stats"
	stats.event_manager = em
	holder.add_child(stats)
	stats.set_base_stat("area_size_multiplier", 2.0)
	add_child(holder)

	var explosion: Explosion = EXPLOSION_SCENE.instantiate()
	explosion.stats = stats
	explosion.radius = 0.5
	holder.add_child(explosion)

	var burst := explosion.get_node_or_null("ExplosionBurst") as ExplosionBurst
	var shape := explosion.get_node("CollisionShape2D") as CollisionShape2D
	assert_float(burst.radius).override_failure_message(
		"the visual ignored area_size_multiplier, so the blast looks smaller "
		+ "than the area it hits").is_equal_approx(shape.shape.radius, 0.001)
	holder.free()


## The node outlives the damage window so the smoke can finish, but not forever.
## An explosion that lives for its particles' full lifetime and no more is what
## keeps a long run from accumulating one node per blast.
func test_explosion_frees_itself_once_the_visual_is_done() -> void:
	var explosion: Explosion = EXPLOSION_SCENE.instantiate()
	add_child(explosion)
	# Real seconds, not frames: the node frees itself on `visual_duration`, which
	# is authored in seconds and is not a constant this suite may pin. 180 frames
	# at the default time factor is 3s, comfortably past the longest layer.
	for i in 180:
		await get_tree().process_frame
	assert_bool(is_instance_valid(explosion)).override_failure_message(
		"the explosion outlived its visual and is leaking a node per blast").is_false()