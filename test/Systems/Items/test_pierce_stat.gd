# GdUnit generated TestSuite
class_name PierceStatTest
extends GdUnitTestSuite

func test_piercing_stat_hits_enemy_behind() -> void:
    var runner := scene_runner("res://test/TestScene.tscn")
    var test_scene := runner.scene()
    runner.set_time_factor(5)
    get_tree().current_scene = test_scene

    var enemy: Enemy = test_scene.get_node("Enemy")
    var enemy2 = preload("res://src/Systems/Enemy.tscn").instantiate()
    # Place second enemy directly behind the first one, on the projectile path
    # Character (100,100) shoots east toward Enemy (300,100), so pierced projectile continues +X.
    # Offset 350 keeps enemy2 outside fist/pistol targeting range (400) so only a
    # piercing projectile can reach it.
    enemy2.global_position = enemy.global_position + Vector2(350, 0)
    test_scene.add_child(enemy2)

    var e1_health: Health = enemy.get_node("Health")
    var e2_health: Health = enemy2.get_node("Health")

    var character: Character = test_scene.get_node("Character")

    var item: Item = _create_pierce_item(1)
    character.item_holder.add_item(item)
    character.weapon_holder.add_weapon(load("res://src/Resources/weapons/Pistol.tres"))

    await runner.simulate_frames(60 * 3)

    # enemy1 hit by pistol + fist; exact HP varies with fist hit timing
    assert_float(e1_health.current_health).is_less(40.0)
    # enemy2 hit by pistol projectile that pierced through enemy1
    assert_float(e2_health.current_health).is_equal(35.0)
    test_scene.free()


func test_no_pierce_does_not_hit_enemy_behind() -> void:
    var runner := scene_runner("res://test/TestScene.tscn")
    var test_scene := runner.scene()
    runner.set_time_factor(5)
    get_tree().current_scene = test_scene

    var enemy: Enemy = test_scene.get_node("Enemy")
    var enemy2 = preload("res://src/Systems/Enemy.tscn").instantiate()
    # Same position as in the pierce test: outside melee/targeting range.
    enemy2.global_position = enemy.global_position + Vector2(350, 0)
    test_scene.add_child(enemy2)

    var e1_health: Health = enemy.get_node("Health")
    var e2_health: Health = enemy2.get_node("Health")

    var character: Character = test_scene.get_node("Character")

    # Pistol.tres now ships with a built-in pierce; strip it (and knockback, to
    # keep hit positions stable) so this test verifies the stat path only.
    var pistol: BaseWeapon = load("res://src/Resources/weapons/Pistol.tres").duplicate(true)
    (pistol.modifiers as Dictionary).erase("pierce")
    (pistol.modifiers as Dictionary).erase("knockback")
    character.weapon_holder.add_weapon(pistol)

    await runner.simulate_frames(60 * 3)

    # enemy1 hit by pistol + fist; exact HP varies with fist hit timing
    assert_float(e1_health.current_health).is_less(40.0)
    # enemy2 untouched: projectile stopped at enemy1 without pierce
    assert_float(e2_health.current_health).is_equal(40.0)
    test_scene.free()


func _create_pierce_item(amount: float) -> Item:
    return ItemBuilder.make_stat_item(
        "Pierce_%s" % str(amount),
        "Pierce: +%s projectile_pierce" % str(amount),
        {"projectile_pierce": {"flat": amount}}
    )
