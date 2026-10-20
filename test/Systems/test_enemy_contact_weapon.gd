# The contact weapon is what makes an enemy hurt on touch. It used to be
# hardcoded - `Enemy._ready` loaded Thorns for every enemy - which made half
# the roster impossible to author: a gunner that shoots cannot also be a
# touch-damage enemy.
#
# It is an export now, with the same default, so every existing enemy, debug
# scenario and test fixture keeps working untouched, and an enemy that should
# not hurt on touch arms nothing at all.
class_name EnemyContactWeaponTest
extends GdUnitTestSuite

const ENEMY_SCENE := "res://src/Systems/Enemy.tscn"

## Physics frames the contact weapon needs to land a hit. Thorns fires at 1.6
## attacks a second, so this covers its first swing with room to spare.
const PHYSICS_FRAMES := 75

var _root: Node2D = null


func after_test() -> void:
    if is_instance_valid(_root):
        _root.free()


## A real enemy in a bare container.
func _spawn_enemy(with_contact_weapon: bool = true) -> Enemy:
    _root = Node2D.new()
    _root.name = "World"
    add_child(_root)
    var enemy: Enemy = load(ENEMY_SCENE).instantiate()
    if not with_contact_weapon:
        # Set before the enemy enters the tree, so its `_ready` sees the null.
        enemy.set("contact_weapon", null)
    _root.add_child(enemy)
    return enemy


func test_default_enemy_arms_the_contact_weapon() -> void:
    var enemy := _spawn_enemy()
    assert_int(enemy.weapon_holder.weapons.size()).is_equal(1)
    assert_bool(enemy.weapon_holder.weapons[0] is ContactWeapon).is_true()


func test_null_contact_weapon_arms_nothing() -> void:
    var enemy := _spawn_enemy(false)
    assert_int(enemy.weapon_holder.weapons.size()).is_equal(0)


func test_an_enemy_with_a_contact_weapon_hurts_on_touch() -> void:
    var enemy := _spawn_enemy()
    var health := DamageableBody.spawn(_root, enemy.global_position)

    for _i in range(PHYSICS_FRAMES):
        await get_tree().physics_frame

    assert_float(health.current_health).override_failure_message(
        "an enemy with a contact weapon did not hurt the body standing in its hitbox"
    ).is_less(100.0)


func test_an_enemy_without_a_contact_weapon_does_not_hurt_on_touch() -> void:
    var enemy := _spawn_enemy(false)
    var health := DamageableBody.spawn(_root, enemy.global_position)

    for _i in range(PHYSICS_FRAMES):
        await get_tree().physics_frame

    assert_float(health.current_health).override_failure_message(
        "an enemy with no contact weapon still hurt the body standing in its hitbox"
    ).is_equal(100.0)
