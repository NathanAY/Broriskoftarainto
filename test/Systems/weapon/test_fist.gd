class_name FistTest
extends GdUnitTestSuite

const FIST := "res://src/Resources/weapons/Fist.tres"

func test_fist_does_damage() -> void:
    var runner := scene_runner(WeaponTestSupport.TEST_SCENE)
    var test_scene := runner.scene()
    runner.set_time_factor(5)
    get_tree().current_scene = test_scene

    var enemy: Enemy = test_scene.get_node("Enemy")
    var e_health := WeaponTestSupport.give_enemy_health(enemy)
    var character: Character = test_scene.get_node("Character")
    WeaponTestSupport.equip_only_weapon(character, FIST)

    await runner.simulate_frames(WeaponTestSupport.FRAMES)

    # The fist connected and the target survived the window. The exact total is
    # deliberately not pinned: it depends on how many swings fit in the frame
    # budget and on the fist's own knockback carrying the target away, which is
    # what made the old hardcoded 35.0 go stale whenever a weapon number moved.
    var left := WeaponTestSupport.health_left(e_health)
    assert_float(left).override_failure_message(
        "the enemy died and freed its Health node").is_greater(0.0)
    assert_float(left).override_failure_message(
        "the fist dealt no damage").is_less(WeaponTestSupport.ENEMY_HEALTH)
    test_scene.free()
