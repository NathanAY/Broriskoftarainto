class_name ThornsTest
extends GdUnitTestSuite

const THORNS := "res://src/Resources/weapons/Thorns.tres"

## Enemies run on the default 10 health, which is already below any "took
## damage" bar, so the target is raised to a budget the assertion can actually
## measure. Same reasoning as `WeaponTestSupport.ENEMY_HEALTH`.
const TARGET_HEALTH := 1000.0


func test_thorns_does_damage() -> void:
    var runner := scene_runner("res://test/TestScene.tscn")
    var test_scene := runner.scene()
    runner.set_time_factor(5)
    get_tree().current_scene = test_scene

    var enemy: Enemy = test_scene.get_node("Enemy")
    var e_health := _give_health(enemy)

    var character: Character = test_scene.get_node("Character")

    for weapon in character.weapon_holder.weapons.duplicate():
        character.weapon_holder.remove_weapon(weapon)

    character.weapon_holder.add_weapon(load(THORNS))
    # Overlap the two hurtboxes, off-centre so the enemy sits ~30 px from the
    # holder's sprite. Thorns damages whatever is inside the holder's own
    # hitbox, so this distance is the point: a `weapon_range` of 0 (or any value
    # below it) would stop the target selector from ever reaching `try_shoot`,
    # and the enemy would keep full health.
    character.global_position = Vector2(270, 100)

    @warning_ignore("redundant_await")
    await runner.simulate_frames(60 * 2)

    assert_float(e_health.current_health).override_failure_message(
        "Thorns dealt no damage to an enemy overlapping the holder's hitbox"
    ).is_less(TARGET_HEALTH)
    test_scene.free()


func _give_health(enemy: Enemy) -> Health:
    var health: Health = enemy.get_node("Health")
    enemy.get_node("Stats").set_base_stat("health", TARGET_HEALTH)
    health.max_health = TARGET_HEALTH
    health.current_health = TARGET_HEALTH
    return health
