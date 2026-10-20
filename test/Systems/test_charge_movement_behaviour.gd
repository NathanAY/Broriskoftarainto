# The charger: it walks in, stops to telegraph, then drives along the
# direction it locked at the end of the windup.
#
# Two things about it are the mechanic rather than the tuning:
#   * the direction is locked when the windup ends and is not re-aimed during
#     the charge, so the player can dodge it, and
#   * the charge speed is a temporary stat boost, because `Enemy._physics_process`
#     clamps the velocity to the movement-speed stat after the behaviour runs.
class_name ChargeMovementBehaviourTest
extends GdUnitTestSuite

const ENEMY_SCENE := "res://src/Systems/Enemy.tscn"
const CHARGE_SCENE := "res://src/Systems/movement/bahaviour/ChargeMovementBehaviour.tscn"

var _root: Node2D = null


func after_test() -> void:
    if is_instance_valid(_root):
        _root.free()


## A real enemy with the charge behaviour bolted on. Its own physics process
## is switched off, so the test drives the behaviour by hand and nothing else
## moves the creature.
func _make_charger() -> Dictionary:
    _root = Node2D.new()
    _root.name = "World"
    add_child(_root)
    var enemy: Enemy = load(ENEMY_SCENE).instantiate()
    _root.add_child(enemy)
    enemy.set_physics_process(false)
    var charge: ChargeMovementBehaviour = load(CHARGE_SCENE).instantiate()
    enemy.add_child(charge)
    var target := Node2D.new()
    _root.add_child(target)
    enemy.set_target_position(target)
    return {"enemy": enemy, "charge": charge, "target": target}


func _kill(enemy: Enemy) -> void:
    var health := enemy.get_node("Health") as Health
    var ctx := DamageContext.new()
    ctx.source = enemy
    ctx.target = enemy
    ctx.base_amount = 1000.0
    ctx.final_amount = 1000.0
    ctx.tags.append("melee")
    health.apply_damage(ctx)


## Walks the charger into the telegraph and then into the charge. The last
## call is the one that sets the charging velocity: entering CHARGE arms the
## speed boost, but the behaviour only writes the velocity on the next tick.
func _charge_up(ctx: Dictionary) -> void:
    var enemy: Enemy = ctx["enemy"]
    var charge: ChargeMovementBehaviour = ctx["charge"]
    var target: Node2D = ctx["target"]
    enemy.global_position = Vector2.ZERO
    target.global_position = Vector2(100, 0)
    charge.process_movement(enemy, 0.1)
    charge.process_movement(enemy, charge.windup_time)
    charge.process_movement(enemy, 0.1)


func test_the_charger_walks_in_telegraphs_charges_and_recovers() -> void:
    var ctx := _make_charger()
    var enemy: Enemy = ctx["enemy"]
    var charge: ChargeMovementBehaviour = ctx["charge"]
    var target: Node2D = ctx["target"]
    enemy.global_position = Vector2.ZERO
    target.global_position = Vector2(100, 0)

    assert_int(charge.state).is_equal(ChargeMovementBehaviour.ChargeState.APPROACH)
    # Close enough: the walk stops and the telegraph starts.
    charge.process_movement(enemy, 0.1)
    assert_int(charge.state).is_equal(ChargeMovementBehaviour.ChargeState.WINDUP)
    # The telegraph runs out and the charge starts.
    charge.process_movement(enemy, charge.windup_time)
    assert_int(charge.state).is_equal(ChargeMovementBehaviour.ChargeState.CHARGE)
    # The charge runs out and the creature recovers.
    charge.process_movement(enemy, charge.charge_duration)
    assert_int(charge.state).is_equal(ChargeMovementBehaviour.ChargeState.RECOVER)
    # The recovery runs out and the creature walks again.
    charge.process_movement(enemy, charge.recover_time)
    assert_int(charge.state).is_equal(ChargeMovementBehaviour.ChargeState.APPROACH)


func test_the_charge_direction_is_locked_when_the_windup_ends() -> void:
    var ctx := _make_charger()
    var enemy: Enemy = ctx["enemy"]
    var charge: ChargeMovementBehaviour = ctx["charge"]
    var target: Node2D = ctx["target"]
    _charge_up(ctx)

    # The player steps aside while the charger is already charging.
    target.global_position = Vector2(0, -100)
    charge.process_movement(enemy, 0.1)

    assert_float(enemy.velocity.normalized().x).override_failure_message(
        "the charge re-aimed at the player instead of driving along the locked direction"
    ).is_equal_approx(1.0, 0.001)
    assert_float(enemy.velocity.normalized().y).is_equal_approx(0.0, 0.001)


func test_the_charge_is_faster_than_the_walk_and_gives_the_speed_back() -> void:
    var ctx := _make_charger()
    var enemy: Enemy = ctx["enemy"]
    var charge: ChargeMovementBehaviour = ctx["charge"]
    var walk_speed: float = enemy.stats.get_movement_speed_px()

    _charge_up(ctx)

    var charge_speed: float = enemy.stats.get_movement_speed_px()
    assert_float(charge_speed).is_equal_approx(walk_speed * charge.charge_speed_scale, 0.001)
    assert_float(enemy.velocity.length()).is_greater(walk_speed)

    charge.process_movement(enemy, charge.charge_duration)
    assert_float(enemy.stats.get_movement_speed_px()).is_equal_approx(walk_speed, 0.001)


func test_the_charge_gives_the_speed_back_when_the_creature_dies() -> void:
    var ctx := _make_charger()
    var enemy: Enemy = ctx["enemy"]
    var walk_speed: float = enemy.stats.get_movement_speed_px()

    _charge_up(ctx)
    assert_float(enemy.stats.get_movement_speed_px()).is_greater(walk_speed)

    _kill(enemy)

    assert_float(enemy.stats.get_movement_speed_px()).override_failure_message(
        "the charge speed boost outlived the creature that died charging"
    ).is_equal_approx(walk_speed, 0.001)
