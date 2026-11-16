# The poison visual. `PoisonEffect` puts a `PoisonParticles` emitter on whatever
# owns the poisoned `Health` node, so these suites pin that any body gets one,
# that its density follows the stack count, and that it goes away with the poison.
class_name PoisonParticlesTest
extends GdUnitTestSuite

const PARTICLES_SCENE: PackedScene = preload("res://src/Scenes/particles/poison_particles.tscn")

var _body: Node2D = null
var _health: Node = null


## A bare body: a Node2D with a `Health` child and the `Node2D/Sprite2D` art
## every actor scene has. Deliberately not an `Enemy` or a `Character`, because
## the point is that the effect needs neither.
func before_test() -> void:
	_body = Node2D.new()
	add_child(_body)
	_health = Node.new()
	_health.name = "Health"
	_body.add_child(_health)
	var inner := Node2D.new()
	inner.name = "Node2D"
	_body.add_child(inner)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = PlaceholderTexture2D.new()
	inner.add_child(sprite)


func after_test() -> void:
	if is_instance_valid(_body):
		_body.free()


func _poison() -> PoisonEffect:
	var poison := PoisonEffect.new()
	_health.add_child(poison)
	poison.start_effect(_health, 1.0, 5.0, 1.0, 100, null)
	return poison


func _particles() -> Array[PoisonParticles]:
	var found: Array[PoisonParticles] = []
	for child in _body.get_children():
		if child is PoisonParticles:
			found.append(child)
	return found


func test_poisoned_body_gets_one_emitting_particle_node() -> void:
	_poison()
	var found := _particles()
	assert_int(found.size()).is_equal(1)
	assert_bool(found[0].emitting).is_true()


func test_more_stacks_reuse_the_node_and_emit_more() -> void:
	var poison := _poison()
	var emitter := _particles()[0]
	var ratio_at_one := emitter.amount_ratio
	poison.add_poison()
	poison.add_poison()
	assert_int(_particles().size()).is_equal(1)
	assert_float(emitter.amount_ratio).is_equal_approx(ratio_at_one * poison.stacks, 0.001)


func test_density_stops_growing_at_full_stacks() -> void:
	var poison := _poison()
	for i in PoisonParticles.FULL_STACKS * 2:
		poison.add_poison()
	assert_float(_particles()[0].amount_ratio).is_equal(1.0)


func test_expired_poison_stops_emitting_then_frees_the_node() -> void:
	var poison := _poison()
	var emitter := _particles()[0]
	poison._on_expire()
	assert_bool(emitter.emitting).is_false()
	await get_tree().create_timer(emitter.lifetime + 0.2).timeout
	assert_bool(is_instance_valid(emitter)).is_false()


## The bubbles are born across the body, so a bigger sprite gets a wider cloud -
## and through its own copy of the material, not the one every instance shares.
func test_emission_area_follows_the_body_sprite() -> void:
	var sprite: Sprite2D = _body.get_node("Node2D/Sprite2D")
	(sprite.texture as PlaceholderTexture2D).size = Vector2(100, 100)
	var small: PoisonParticles = PARTICLES_SCENE.instantiate()
	_body.add_child(small)
	sprite.scale = Vector2(3, 3)
	var big: PoisonParticles = PARTICLES_SCENE.instantiate()
	_body.add_child(big)
	var small_radius: float = (small.process_material as ParticleProcessMaterial).emission_sphere_radius
	var big_radius: float = (big.process_material as ParticleProcessMaterial).emission_sphere_radius
	assert_float(big_radius).is_equal_approx(small_radius * 3.0, 0.001)
