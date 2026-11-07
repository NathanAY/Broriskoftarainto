# The front shield: a hit that lands on the enemy's front arc does no damage,
# and a hit from anywhere else lands normally.
#
# The shield reads the facing the movement behaviours already write (`flip_h`
# on the sprite), so the test flips the sprite rather than inventing a facing
# API the enemy does not have.
class_name FrontShieldTest
extends GdUnitTestSuite

const ENEMY_SCENE := "res://src/Systems/Enemy.tscn"
const SHIELD_SCENE := "res://src/Systems/damage/FrontShield.tscn"

var _root: Node2D = null


func after_test() -> void:
	if is_instance_valid(_root):
		_root.free()


## An enemy carrying a front shield.
func _make_shielded_enemy() -> Enemy:
	_root = Node2D.new()
	_root.name = "World"
	add_child(_root)
	var enemy: Enemy = load(ENEMY_SCENE).instantiate()
	enemy.set_physics_process(false)
	_root.add_child(enemy)
	var shield: FrontShield = load(SHIELD_SCENE).instantiate()
	enemy.add_child(shield)
	enemy.global_position = Vector2.ZERO
	return enemy


## Deals one small hit to `enemy` from `source_position` and returns the health
## the enemy lost.
func _hit_from(enemy: Enemy, source_position: Vector2) -> float:
	var source := Node2D.new()
	_root.add_child(source)
	source.global_position = source_position
	var health := enemy.get_node("Health") as Health
	var health_before := health.current_health
	var ctx := DamageContext.new()
	ctx.source = source
	ctx.target = enemy
	ctx.base_amount = 2.0
	ctx.final_amount = ctx.base_amount
	ctx.tags.append("melee")
	health.apply_damage(ctx)
	return health_before - health.current_health


func test_the_shield_blocks_a_hit_from_the_front() -> void:
	var enemy := _make_shielded_enemy()

	var lost := _hit_from(enemy, Vector2(100.0, 0.0))

	assert_float(lost).override_failure_message(
		"the shield let a hit from the front through"
	).is_equal(0.0)


func test_the_shield_lets_a_hit_from_behind_through() -> void:
	var enemy := _make_shielded_enemy()

	var lost := _hit_from(enemy, Vector2(-100.0, 0.0))

	assert_float(lost).override_failure_message(
		"the shield blocked a hit from behind"
	).is_greater(0.0)


func test_the_shield_does_not_cover_the_sides() -> void:
	var enemy := _make_shielded_enemy()

	# Directly above a horizontally-facing creature is 90 degrees off the arc.
	var lost := _hit_from(enemy, Vector2(0.0, -100.0))

	assert_float(lost).override_failure_message(
		"the shield covered a side that is outside its front arc"
	).is_greater(0.0)


func test_the_shield_turns_with_the_sprite() -> void:
	var enemy := _make_shielded_enemy()
	var sprite := enemy.get_node("Node2D/Sprite2D") as Sprite2D
	sprite.flip_h = true

	var lost := _hit_from(enemy, Vector2(-100.0, 0.0))

	assert_float(lost).override_failure_message(
		"the shield did not follow the direction the sprite faces"
	).is_equal(0.0)
