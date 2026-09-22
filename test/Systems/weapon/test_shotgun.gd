class_name ShotgunTest
extends GdUnitTestSuite

func test_shotgun_does_damage() -> void:
    var runner := scene_runner("res://test/TestScene.tscn")
    var test_scene := runner.scene()
    runner.set_time_factor(5)
    get_tree().current_scene = test_scene

    var enemy: Enemy = test_scene.get_node("Enemy")
    var e_health: Health = enemy.get_node("Health")

    var character: Character = test_scene.get_node("Character")

    for weapon in character.weapon_holder.weapons.duplicate():
        character.weapon_holder.remove_weapon(weapon)

    character.weapon_holder.add_weapon(load("res://src/Resources/weapons/Shotgun.tres"))

    await runner.simulate_frames(60 * 3.0)

    # shotgun has multiple pellet with random spread, so a single hit can do random damage
    assert_float(e_health.current_health).is_between(30.0, 38.0)
    test_scene.free()
