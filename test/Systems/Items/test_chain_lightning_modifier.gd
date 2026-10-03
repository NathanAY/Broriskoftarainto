# GdUnit generated TestSuite
class_name ChainLighningModifierTest
extends GdUnitTestSuite

func test_chain_lightnin_modifier() -> void:
    var runner := scene_runner("res://test/TestScene.tscn")
    var test_scene := runner.scene()
    runner.set_time_factor(5)
    get_tree().current_scene = test_scene

    var enemy: Enemy = test_scene.get_node("Enemy")
    var enemy2 = preload("res://src/Systems/Enemy.tscn").instantiate()
    enemy2.global_position = enemy.global_position + Vector2(100, 300)
    test_scene.add_child(enemy2)
    
    # Both targets get the shared health budget rather than the `Stats` default of
    # 10. A dead enemy plays its death animation and frees its node, so a target
    # that dies inside the window leaves `health` dangling and reading it stalls
    # the runner on the debugger prompt - see WeaponTestSupport for the why.
    var e1_health: Health = WeaponTestSupport.give_enemy_health(enemy)
    var e2_health: Health = WeaponTestSupport.give_enemy_health(enemy2)

    var character: Character = test_scene.get_node("Character")
    
    var item: Item = _create_item("ChainModifier.tscn", 1)
    character.item_holder.add_item(item)
    
    @warning_ignore("redundant_await")
    await runner.simulate_frames(60 * 3)

    # Read through `health_left`, which reports -1.0 for a freed node so a dead
    # target fails as an ordinary assertion instead of a script error. The exact
    # total is not pinned: how many swings fit in the frame budget, and the
    # chain's own reach, both decide it.
    # enemy1 is hit by the fist; enemy2 only by the chained projectile.
    assert_float(WeaponTestSupport.health_left(e1_health)).override_failure_message(
        "the enemy died and freed its Health node").is_less(WeaponTestSupport.ENEMY_HEALTH)
    assert_float(WeaponTestSupport.health_left(e2_health)).override_failure_message(
        "the enemy died and freed its Health node").is_less(WeaponTestSupport.ENEMY_HEALTH)
    test_scene.free()


func _create_item(modifier_name: String, amount: float) -> Item:
    var modifier_scene: PackedScene = load("res://src/Systems/Items/modifiers/" + modifier_name)
    return ItemBuilder.make_effect_item(
        "Buff_%s_%s" % [modifier_name, str(amount)],
        "Buff: +%s %s" % [amount, modifier_name],
        modifier_scene
    )
