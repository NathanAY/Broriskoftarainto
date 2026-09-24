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
    
    var e1_health: Health = enemy.get_node("Health")
    var e2_health: Health = enemy2.get_node("Health")

    var character: Character = test_scene.get_node("Character")
    
    var item: Item = _create_item("ChainModifier.tscn", 1)
    character.item_holder.add_item(item)
        
    await runner.simulate_frames(60 * 3)

    #enemy1 hit by fist twice (2 x 10 damage, fist only - no pistol here)
    assert_float(e1_health.current_health).is_less(35.0)
    #enemy2 hit by chain lightning projectile twice (2 x 10 damage)
    assert_float(e2_health.current_health).is_less(35.0)
    test_scene.free()


func _create_item(modifier_name: String, amount: float) -> Item:
    var modifier_scene: PackedScene = load("res://src/Systems/Items/modifiers/" + modifier_name)
    return ItemBuilder.make_effect_item(
        "Buff_%s_%s" % [modifier_name, str(amount)],
        "Buff: +%s %s" % [amount, modifier_name],
        modifier_scene
    )
