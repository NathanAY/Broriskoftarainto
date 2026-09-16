class_name ThornsTest
extends GdUnitTestSuite

func test_thorns_does_damage() -> void:
    var runner := scene_runner("res://test/TestScene.tscn")
    var test_scene := runner.scene()
    runner.set_time_factor(5)
    get_tree().current_scene = test_scene

    var enemy: Enemy = test_scene.get_node("Enemy")
    var e_health: Health = enemy.get_node("Health")

    var character: Character = test_scene.get_node("Character")

    for weapon in character.weapon_holder.weapons.duplicate():
        character.weapon_holder.remove_weapon(weapon)

    character.weapon_holder.add_weapon(load("res://src/Resources/weapons/Thorns.tres"))
    # set the character position to enemy to everlap sprites and do damage by Thorns   
    character.global_position = Vector2(270, 100)

    await runner.simulate_frames(60 * 2)

    assert_float(e_health.current_health).is_less(40.0)
    test_scene.free()
