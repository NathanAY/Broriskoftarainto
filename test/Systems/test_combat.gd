# GdUnit generated TestSuite
class_name CombatTest
extends GdUnitTestSuite

# simulate_frames() advances real process frames and game-time per frame depends
# on the actual framerate (headless runs uncapped), so a fixed frame budget is not
# deterministic across windowed/headless runs. Poll for combat conditions instead.
const ENEMY_MAX_FRAMES: int = 60 * 20

func test_character_in_combat() -> void:
    var runner := scene_runner("res://test/TestScene.tscn")
    var test_scene := runner.scene()
    runner.set_time_factor(5)
    get_tree().current_scene = test_scene

    var _character: Character = test_scene.get_node("Character")
    var enemy = test_scene.get_node("Enemy")
    var initial_position = enemy.global_position
    var e_health: Health = enemy.get_node("Health")

    assert_float(e_health.current_health).is_equal(40.0)

    var frames := 0
    while e_health.current_health >= 20.0 and frames < ENEMY_MAX_FRAMES:
        await runner.simulate_frames(5)
        frames += 5
    assert_float(e_health.current_health).is_less(20.0)
    # Change position because fist weapon has a knockback
    enemy.global_position = initial_position

    while is_instance_valid(enemy) and frames < ENEMY_MAX_FRAMES:
        await runner.simulate_frames(5)
        frames += 5
    assert_bool(is_instance_valid(enemy)).is_false()

    test_scene.free()
