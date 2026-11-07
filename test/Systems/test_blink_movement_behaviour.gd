# The blinker: it chases like the basic enemy, but every `blink_interval` it
# teleports to a random point within `blink_radius` of its target.
#
# The teleport is the mechanic rather than the numbers: the body has to leave
# its old spot for a new one near the player, and it must not re-aim while it is
# there. The test drives the behaviour by hand, like the charger suite, so no
# physics frame moves the body on its own.
class_name BlinkMovementBehaviourTest
extends GdUnitTestSuite

const ENEMY_SCENE := "res://src/Systems/Enemy.tscn"
const BLINK_SCENE := "res://src/Systems/movement/bahaviour/BlinkMovementBehaviour.tscn"

var _root: Node2D = null


func after_test() -> void:
	if is_instance_valid(_root):
		_root.free()


## A real enemy with the blink behaviour bolted on. Its own physics process is
## switched off, so the test drives the behaviour by hand.
func _make_blinker() -> Dictionary:
	_root = Node2D.new()
	_root.name = "World"
	add_child(_root)
	var enemy: Enemy = load(ENEMY_SCENE).instantiate()
	_root.add_child(enemy)
	enemy.set_physics_process(false)
	var blink: BlinkMovementBehaviour = load(BLINK_SCENE).instantiate()
	enemy.add_child(blink)
	var target := Node2D.new()
	_root.add_child(target)
	enemy.set_target_position(target)
	return {"enemy": enemy, "blink": blink, "target": target}


func test_the_blinker_walks_towards_its_target_between_blinks() -> void:
	var ctx := _make_blinker()
	var enemy: Enemy = ctx["enemy"]
	var blink: BlinkMovementBehaviour = ctx["blink"]
	var target: Node2D = ctx["target"]
	enemy.global_position = Vector2.ZERO
	target.global_position = Vector2(400.0, 0.0)

	blink.process_movement(enemy, 0.1)

	assert_float(enemy.velocity.x).override_failure_message(
		"the blinker did not walk towards its target between blinks"
	).is_greater(0.0)
	assert_float(enemy.velocity.length()).is_equal_approx(
		enemy.stats.get_movement_speed_px(), 0.001)


func test_the_blinker_reappears_near_the_target_after_the_interval() -> void:
	var ctx := _make_blinker()
	var enemy: Enemy = ctx["enemy"]
	var blink: BlinkMovementBehaviour = ctx["blink"]
	var target: Node2D = ctx["target"]
	enemy.global_position = Vector2.ZERO
	target.global_position = Vector2(500.0, 0.0)

	# Just under the interval: it is still walking, so it has not teleported.
	blink.process_movement(enemy, blink.blink_interval - 0.01)
	assert_that(enemy.global_position).is_equal(Vector2.ZERO)

	# Crossing the interval teleports it into the ring around the target.
	blink.process_movement(enemy, 0.02)
	var distance := enemy.global_position.distance_to(target.global_position)
	assert_float(distance).override_failure_message(
		"the blinker did not reappear near its target"
	).is_between(blink.min_blink_distance, blink.blink_radius)


func test_a_blink_does_not_carry_the_old_velocity() -> void:
	var ctx := _make_blinker()
	var enemy: Enemy = ctx["enemy"]
	var blink: BlinkMovementBehaviour = ctx["blink"]
	var target: Node2D = ctx["target"]
	enemy.global_position = Vector2.ZERO
	target.global_position = Vector2(500.0, 0.0)

	blink.process_movement(enemy, blink.blink_interval - 0.01)
	assert_float(enemy.velocity.length()).is_greater(0.0)

	blink.process_movement(enemy, 0.02)

	assert_float(enemy.velocity.length()).override_failure_message(
		"the blinker kept walking after it reappeared"
	).is_equal(0.0)
