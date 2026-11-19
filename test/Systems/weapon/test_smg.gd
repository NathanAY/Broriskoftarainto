class_name SmgTest
extends GdUnitTestSuite

const SMG := "res://src/Resources/weapons/Smg.tres"
const PISTOL := "res://src/Resources/weapons/Pistol.tres"

func test_smg_trades_damage_for_fire_rate() -> void:
    var smg: BaseWeapon = load(SMG)
    var pistol: BaseWeapon = load(PISTOL)
    assert_float(smg.base_damage).is_less(pistol.base_damage)
    assert_float(smg.base_attack_speed).is_greater(pistol.base_attack_speed)

func test_smg_sprite_is_drawn_at_weapon_size_not_source_size() -> void:
    var runner := scene_runner(WeaponTestSupport.TEST_SCENE)
    var test_scene := runner.scene()
    get_tree().current_scene = test_scene
    var character: Character = test_scene.get_node("Character")
    WeaponTestSupport.equip_only_weapon(character, SMG)
    var visual: Sprite2D = character.weapon_holder.weapons[0].sprite_node
    var drawn := visual.texture.get_width() * visual.scale.x
    assert_float(float(visual.texture.get_width())).override_failure_message(
        "the SMG must use its full-resolution source art").is_greater(AssetSizes.WEAPON_SPRITE)
    assert_float(drawn).is_equal_approx(AssetSizes.WEAPON_SPRITE, 0.01)
    test_scene.free()

func test_smg_bullets_deviate_from_aim_line() -> void:
    var runner := scene_runner(WeaponTestSupport.TEST_SCENE)
    var test_scene := runner.scene()
    get_tree().current_scene = test_scene
    var character: Character = test_scene.get_node("Character")
    var enemy: Enemy = test_scene.get_node("Enemy")
    WeaponTestSupport.equip_only_weapon(character, SMG)
    var weapon: SmgWeapon = character.weapon_holder.weapons[0]

    var aim: Vector2 = (enemy.global_position - weapon.sprite_node.global_position).normalized()
    var max_angle := 0.0
    var min_signed := 0.0
    var max_signed := 0.0
    for i in 40:
        weapon.try_shoot([enemy])
        var p: Projectile = test_scene.get_children().filter(func(n): return n is Projectile).back()
        var signed := aim.angle_to(p.direction)
        min_signed = minf(min_signed, signed)
        max_signed = maxf(max_signed, signed)
        max_angle = maxf(max_angle, absf(signed))
        p.free()

    assert_float(max_angle).override_failure_message("every bullet flew dead straight").is_greater(0.0)
    assert_float(max_angle).override_failure_message("a bullet left the spread cone").is_less_equal(deg_to_rad(weapon.spread_angle) + 0.0001)
    assert_bool(min_signed < 0.0 and max_signed > 0.0).override_failure_message("spread only goes one way").is_true()
    test_scene.free()

func test_smg_does_damage() -> void:
    var runner := scene_runner(WeaponTestSupport.TEST_SCENE)
    var test_scene := runner.scene()
    runner.set_time_factor(5)
    get_tree().current_scene = test_scene
    var enemy: Enemy = test_scene.get_node("Enemy")
    var e_health := WeaponTestSupport.give_enemy_health(enemy)
    var character: Character = test_scene.get_node("Character")
    WeaponTestSupport.equip_only_weapon(character, SMG)

    @warning_ignore("redundant_await")
    await runner.simulate_frames(WeaponTestSupport.FRAMES)

    var left := WeaponTestSupport.health_left(e_health)
    assert_float(left).override_failure_message("the enemy died and freed its Health node").is_greater(0.0)
    assert_float(left).override_failure_message("the SMG dealt no damage").is_less(WeaponTestSupport.ENEMY_HEALTH)
    test_scene.free()
