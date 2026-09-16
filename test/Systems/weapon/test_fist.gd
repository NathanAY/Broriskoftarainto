class_name FistTest
extends GdUnitTestSuite

func test_fist_does_damage() -> void:
    var runner := scene_runner("res://test/TestScene.tscn")
    var test_scene := runner.scene()
    runner.set_time_factor(5)
    get_tree().current_scene = test_scene

    var enemy: Enemy = test_scene.get_node("Enemy")
    var e_health: Health = enemy.get_node("Health")

    var character: Character = test_scene.get_node("Character")

    for weapon in character.weapon_holder.weapons.duplicate():
        character.weapon_holder.remove_weapon(weapon)

    character.weapon_holder.add_weapon(load("res://src/Resources/weapons/Fist.tres"))

    await runner.simulate_frames(60 * 2)

    # fist base_damage is 5, so a single hit in 2 seconds: 40 - 5 = 35
    assert_float(e_health.current_health).is_equal(35.0)
    test_scene.free()
