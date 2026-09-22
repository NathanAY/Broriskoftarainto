# GdUnit generated TestSuite
class_name CombatTest
extends GdUnitTestSuite

func test_character_in_combat() -> void:
    var runner := scene_runner("res://test/TestScene.tscn")
    var test_scene := runner.scene()
    runner.set_time_factor(5)
    get_tree().current_scene = test_scene

    var _character: Character = test_scene.get_node("Character")
    var enemy = test_scene.get_node("Enemy")
    var e_health: Health = enemy.get_node("Health")

    assert_float(e_health.current_health).is_equal(40.0)

    await runner.simulate_frames(int(60 * 3.2))
    assert_float(e_health.current_health).is_less(30.0)
    
    await runner.simulate_frames(60 * 2)
    assert_bool(is_instance_valid(enemy)).is_false()

    test_scene.free()
