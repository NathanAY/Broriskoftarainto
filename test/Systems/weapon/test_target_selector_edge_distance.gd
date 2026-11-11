extends GdUnitTestSuite

## A weapon's range is measured to the edge of the target's hitbox, not to its
## centre, so a big creature is hit as soon as its body is in reach.

const BIG_RADIUS := 100.0
const SMALL_RADIUS := 10.0
const RANGE := 250.0

var _arena: Node2D
var _holder: Node2D


func before_test() -> void:
	# Targets and holder live under one Node2D, as in the game: a CanvasItem whose
	# parent is not a CanvasItem is put in a shared engine group, which
	# `ClosestTargetSelector` would read as "same team".
	_arena = auto_free(Node2D.new())
	add_child(_arena)
	_holder = Node2D.new()
	_arena.add_child(_holder)


func _make_target(at: Vector2, radius: float) -> Node2D:
	var body := auto_free(CharacterBody2D.new()) as CharacterBody2D
	body.add_to_group("damageable")
	var hitbox := Area2D.new()
	hitbox.name = "Hitbox"
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"  # the selectors look it up by this name, as in the enemy scenes
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	hitbox.add_child(shape)
	body.add_child(hitbox)
	_arena.add_child(body)
	body.global_position = at
	return body


func _selectors() -> Array[TargetSelector]:
	return [
		ClosestTargetSelector.new(),
		AllTargetsInRangeSelector.new(),
		LowestHealthTargetSelector.new(),
		HighestHealthTargetSelector.new(),
		RandomTargetSelector.new(),
	]


## Centre is out of range, hitbox edge is inside it: every selector finds it.
func test_big_target_is_found_by_its_edge_not_its_centre() -> void:
	var big := _make_target(Vector2(RANGE + BIG_RADIUS * 0.5, 0), BIG_RADIUS)
	var centre_distance := _holder.global_position.distance_to(big.global_position)
	assert_float(centre_distance).is_greater(RANGE)
	for selector in _selectors():
		# The health selectors read a Health node; a stub with the one field they read.
		if big.get_node_or_null("Health") == null:
			var stub := GDScript.new()
			stub.source_code = "extends Node\nvar current_health := 5.0\n"
			stub.reload()
			var health := Node.new()
			health.name = "Health"
			health.set_script(stub)
			big.add_child(health)
		var found := selector.find_targets(_holder, RANGE, _holder)
		assert_array(found).override_failure_message(
			"%s ignored a target whose hitbox edge is in range" % selector.get_script().get_global_name()
		).contains([big])


## A target whose edge is still beyond the range is not found.
func test_target_beyond_its_edge_is_not_found() -> void:
	var far := _make_target(Vector2(RANGE + BIG_RADIUS + 50.0, 0), BIG_RADIUS)
	for selector in [ClosestTargetSelector.new(), AllTargetsInRangeSelector.new()]:
		assert_array(selector.find_targets(_holder, RANGE, _holder)).is_empty()
	assert_object(far).is_not_null()


## Closest is ordered by the gap to the hitbox edge, so a big creature whose
## edge is nearer wins over a small one whose centre is nearer.
func test_closest_orders_by_edge_gap() -> void:
	var big := _make_target(Vector2(150, 0), BIG_RADIUS)  # edge gap 50
	var small := _make_target(Vector2(100, 0), SMALL_RADIUS)  # edge gap 90
	var found := ClosestTargetSelector.new().find_targets(_holder, RANGE, _holder)
	assert_array(found).has_size(2)
	assert_object(found[0]).is_same(big)
	assert_object(found[1]).is_same(small)


## A node with no collision shape falls back to its centre.
func test_target_without_a_shape_uses_its_centre() -> void:
	var bare := auto_free(Node2D.new()) as Node2D
	bare.add_to_group("damageable")
	_arena.add_child(bare)
	bare.global_position = Vector2(RANGE - 1.0, 0)
	assert_array(AllTargetsInRangeSelector.new().find_targets(_holder, RANGE, _holder)).contains([bare])
	bare.global_position = Vector2(RANGE + 1.0, 0)
	assert_array(AllTargetsInRangeSelector.new().find_targets(_holder, RANGE, _holder)).is_empty()
