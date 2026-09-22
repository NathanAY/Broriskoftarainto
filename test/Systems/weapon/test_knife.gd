class_name KnifeTest
extends GdUnitTestSuite

func test_knife_does_damage() -> void:
    var runner := scene_runner("res://test/TestScene.tscn")
    var test_scene := runner.scene()
    runner.set_time_factor(5)
    get_tree().current_scene = test_scene

    var enemy: Enemy = test_scene.get_node("Enemy")
    var e_health: Health = enemy.get_node("Health")

    var character: Character = test_scene.get_node("Character")

    for weapon in character.weapon_holder.weapons.duplicate():
        character.weapon_holder.remove_weapon(weapon)

    character.weapon_holder.add_weapon(load("res://src/Resources/weapons/Knife.tres"))

    await runner.simulate_frames(60 * 2)

    # the knife hit must damage the enemy; its built-in poison may or may not
    # land a tick inside this short window, so only assert the hit landed
    assert_float(e_health.current_health).is_less(40.0)
    test_scene.free()
