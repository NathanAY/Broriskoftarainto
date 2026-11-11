extends GdUnitTestSuite

## The fist hits in rectangles along its flight: its own footprint at the start,
## then, each time it arrives at the end of a stretch, the ground that stretch just
## covered. A target is only hit once the fist has actually got to it.

const SWING_SCENE := "res://src/Systems/weapon/MeleeWeaponNode.tscn"
const TARGET_RADIUS := 30.0

var _arena: Node2D
var _swing: Node2D
var _reach_px: float


func before_test() -> void:
	_arena = auto_free(Node2D.new())
	add_child(_arena)
	var holder := Node2D.new()
	holder.name = "Holder"
	_arena.add_child(holder)
	_swing = (load(SWING_SCENE) as PackedScene).instantiate()
	_arena.add_child(_swing)
	var weapon := MeleeWeapon.new()
	weapon.weapon_range = 1.0
	_swing.weapon_data = weapon
	_swing.holder = holder
	_swing.direction = Vector2.RIGHT
	_swing._attack_origin_global = Vector2.ZERO
	_reach_px = weapon.get_range_px()


## An enemy-like target: a damageable body with a `Hitbox` area and a stub
## `Health` that counts the hits it takes.
func _make_target(at: Vector2, radius: float = TARGET_RADIUS) -> Node2D:
	var body := auto_free(CharacterBody2D.new()) as CharacterBody2D
	body.add_to_group("damageable")
	var hitbox := Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 4
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	hitbox.add_child(shape)
	body.add_child(hitbox)
	var stub := GDScript.new()
	stub.source_code = "extends Node\nvar current_health := 100.0\nvar hits := 0\nfunc apply_damage(_c) -> bool:\n\thits += 1\n\treturn true\n"
	stub.reload()
	var health := Node.new()
	health.name = "Health"
	health.set_script(stub)
	body.add_child(health)
	_arena.add_child(body)
	body.global_position = at
	return body


func _hits(target: Node2D) -> int:
	return target.get_node("Health").hits


func _segment_count() -> int:
	return _swing.SEGMENTS


func test_there_are_three_or_four_segments() -> void:
	assert_int(_segment_count()).is_between(3, 4)


## When the swing starts only the fist's own footprint is hit: a target at the far
## end of the path, or even one flight-stretch ahead, is untouched until the fist
## gets there.
func test_only_the_fist_footprint_is_hit_at_the_start() -> void:
	var under := _make_target(Vector2(_swing.first_segment_end() * 0.5, 0))
	var ahead := _make_target(Vector2(_swing.segment_end(1), 0), TARGET_RADIUS * 0.5)
	var far := _make_target(Vector2(_swing.segment_end(_segment_count()) - TARGET_RADIUS, 0), TARGET_RADIUS * 0.5)
	await get_tree().physics_frame
	_swing.hit_segment(0)
	assert_int(_hits(under)).is_equal(1)
	assert_int(_hits(ahead)).is_equal(0)
	assert_int(_hits(far)).is_equal(0)


## Stretch k is hit only when the fist arrives at its end, and it covers exactly
## the ground between the end of stretch k-1 and the end of stretch k. The last one
## ends at the fist's tip at full extension, so nothing past it is ever hit.
func test_each_segment_hits_the_stretch_it_just_covered() -> void:
	var targets: Array[Node2D] = []
	targets.append(null)  # stretch 0 is the footprint, covered by its own test
	for k in range(1, _segment_count() + 1):
		targets.append(_make_target(Vector2(_swing.segment_end(k) - TARGET_RADIUS, 0), TARGET_RADIUS * 0.5))
	var beyond := _make_target(Vector2(_swing.segment_end(_segment_count()) + TARGET_RADIUS * 3.0, 0), TARGET_RADIUS * 0.5)
	await get_tree().physics_frame
	for i in range(0, _segment_count() + 1):
		_swing.hit_segment(i)
		for k in range(1, _segment_count() + 1):
			assert_int(_hits(targets[k])).override_failure_message(
				"after segment %d, target %d was hit %d times" % [i, k, _hits(targets[k])]
			).is_equal(1 if k <= i else 0)
		assert_int(_hits(beyond)).override_failure_message(
			"a target past the fist's full extension was hit after segment %d" % i
		).is_equal(0)


## A target sitting across a segment boundary is hit once, not once per segment.
func test_a_target_is_only_hit_once_per_swing() -> void:
	var edge := _make_target(Vector2(_swing.segment_end(1), 0), TARGET_RADIUS)
	await get_tree().physics_frame
	for i in range(0, _segment_count() + 1):
		_swing.hit_segment(i)
	assert_int(_hits(edge)).is_equal(1)


## Behind the fist and off to the side are never hit.
func test_targets_behind_or_to_the_side_are_missed() -> void:
	var behind := _make_target(Vector2(-200, 0))
	var aside := _make_target(Vector2(_reach_px * 0.5, 200))
	await get_tree().physics_frame
	for i in range(0, _segment_count() + 1):
		_swing.hit_segment(i)
	assert_int(_hits(behind)).is_equal(0)
	assert_int(_hits(aside)).is_equal(0)


## The wielder is never hit by its own swing.
func test_the_holder_is_not_hit() -> void:
	var holder_body := _make_target(Vector2(_reach_px * 0.3, 0))
	_swing.holder = holder_body
	await get_tree().physics_frame
	for i in range(0, _segment_count() + 1):
		_swing.hit_segment(i)
	assert_int(_hits(holder_body)).is_equal(0)
