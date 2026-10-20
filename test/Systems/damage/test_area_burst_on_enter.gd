# The death burst: the damage source behind an enemy that detonates when it
# dies. It is an optional child on the enemy scene, and it fires once, when
# the enemy dies.
#
# The blast is a group scan over "damageable", not a physics overlap: the enemy
# that died has just left the group, so the corpse is not a target and
# everything else standing in the radius is.
class_name AreaBurstOnEnterTest
extends GdUnitTestSuite

const ENEMY_SCENE := "res://src/Systems/Enemy.tscn"
const BURST_SCENE := "res://src/Systems/damage/AreaBurstOnEnter.tscn"

## Blast damage the burst deals.
const BLAST_DAMAGE := 25.0

var _root: Node2D = null


func after_test() -> void:
    if is_instance_valid(_root):
        _root.free()


## An enemy that carries a death burst.
func _spawn_bursting_enemy(blast_radius: float = 0.5) -> Enemy:
    _root = Node2D.new()
    _root.name = "World"
    add_child(_root)
    var enemy: Enemy = load(ENEMY_SCENE).instantiate()
    _root.add_child(enemy)
    var burst: AreaBurstOnEnter = load(BURST_SCENE).instantiate()
    burst.blast_radius = blast_radius
    burst.blast_damage = BLAST_DAMAGE
    enemy.add_child(burst)
    return enemy


func _kill(enemy: Enemy) -> void:
    var health := enemy.get_node("Health") as Health
    var ctx := DamageContext.new()
    ctx.source = enemy
    ctx.target = enemy
    ctx.base_amount = 1000.0
    ctx.final_amount = 1000.0
    ctx.tags.append("melee")
    health.apply_damage(ctx)


func test_the_burst_hits_a_damageable_inside_the_radius() -> void:
    var enemy := _spawn_bursting_enemy()
    var health := DamageableBody.spawn(_root, Vector2(50, 0))

    _kill(enemy)

    assert_float(health.current_health).override_failure_message(
        "the death burst did not hit a damageable standing inside its radius"
    ).is_equal(100.0 - BLAST_DAMAGE)


func test_the_burst_misses_a_damageable_outside_the_radius() -> void:
    var enemy := _spawn_bursting_enemy()
    var health := DamageableBody.spawn(_root, Vector2(2000, 0))

    _kill(enemy)

    assert_float(health.current_health).override_failure_message(
        "the death burst hit a damageable standing outside its radius"
    ).is_equal(100.0)


func test_the_burst_ignores_a_body_that_is_not_damageable() -> void:
    var enemy := _spawn_bursting_enemy()
    var health := DamageableBody.spawn(_root, Vector2(50, 0), 100.0, false)

    _kill(enemy)

    assert_float(health.current_health).override_failure_message(
        "the death burst hit a body that is not in the damageable group"
    ).is_equal(100.0)


func test_the_burst_fires_only_once() -> void:
    var enemy := _spawn_bursting_enemy()
    var health := DamageableBody.spawn(_root, Vector2(50, 0))

    _kill(enemy)
    var after_first := health.current_health

    # A duplicate death event must not blast a second time.
    var ctx := DamageContext.new()
    ctx.source = enemy
    ctx.target = enemy
    ctx.base_amount = 1000.0
    ctx.final_amount = 1000.0
    (enemy.get_node("EventManager") as EventManager).emit_event(
        "on_death", {"self": enemy, "damage_context": ctx})

    assert_float(health.current_health).is_equal(after_first)
