# GdUnit generated TestSuite
class_name PistolTest
extends GdUnitTestSuite

const PISTOL := "res://src/Resources/weapons/Pistol.tres"

func test_pistol_does_damage() -> void:
    var runner := scene_runner(WeaponTestSupport.TEST_SCENE)
    var test_scene := runner.scene()
    runner.set_time_factor(5)
    get_tree().current_scene = test_scene

    var enemy: Enemy = test_scene.get_node("Enemy")
    var e_health := WeaponTestSupport.give_enemy_health(enemy)
    var character: Character = test_scene.get_node("Character")
    WeaponTestSupport.equip_only_weapon(character, PISTOL)

    await runner.simulate_frames(WeaponTestSupport.FRAMES)

    # The pistol connected and the target survived the window. How many shots
    # land inside the frame budget varies, so the test asserts the outcome
    # ("hit, and still standing") instead of a hardcoded remaining-health value.
    var left := WeaponTestSupport.health_left(e_health)
    assert_float(left).override_failure_message(
        "the enemy died and freed its Health node").is_greater(0.0)
    assert_float(left).override_failure_message(
        "the pistol dealt no damage").is_less(WeaponTestSupport.ENEMY_HEALTH)
    test_scene.free()
