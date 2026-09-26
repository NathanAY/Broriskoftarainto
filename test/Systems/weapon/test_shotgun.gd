class_name ShotgunTest
extends GdUnitTestSuite

const SHOTGUN := "res://src/Resources/weapons/Shotgun.tres"

func test_shotgun_does_damage() -> void:
    var runner := scene_runner(WeaponTestSupport.TEST_SCENE)
    var test_scene := runner.scene()
    runner.set_time_factor(5)
    get_tree().current_scene = test_scene

    var enemy: Enemy = test_scene.get_node("Enemy")
    var e_health := WeaponTestSupport.give_enemy_health(enemy)
    var character: Character = test_scene.get_node("Character")
    WeaponTestSupport.equip_only_weapon(character, SHOTGUN)

    await runner.simulate_frames(WeaponTestSupport.FRAMES)

    # A shotgun blast is several pellets with random spread, so the damage total
    # is random by design: the test asserts that the blast connected and that the
    # target outlived the window, not an exact remaining-health value.
    var left := WeaponTestSupport.health_left(e_health)
    assert_float(left).override_failure_message(
        "the enemy died and freed its Health node").is_greater(0.0)
    assert_float(left).override_failure_message(
        "the shotgun dealt no damage").is_less(WeaponTestSupport.ENEMY_HEALTH)
    test_scene.free()
