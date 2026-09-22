# GdUnit generated TestSuite
class_name BuffInCombatTest
extends GdUnitTestSuite

func test_add_buff_item_to_character_in_combat() -> void:
    var runner := scene_runner("res://test/TestScene.tscn")
    var test_scene := runner.scene()
    runner.set_time_factor(5)
    get_tree().current_scene = test_scene

    var character: Character = test_scene.get_node("Character")
    
    var buff_item: Item = _create_buff_item("attack_speed", 2.5)
    character.item_holder.add_item(buff_item)
    
    var initial_attack_speed: float  = character.stats.get_stat("attack_speed")
    assert_float(initial_attack_speed).is_equal(1.0)
    
    await runner.simulate_frames(int(60 * 2.2))

    var next_attack_speed: float  = character.stats.get_stat("attack_speed")
    assert_float(next_attack_speed).is_greater(3.0)
    test_scene.free()


func _create_buff_item(stat_name: String, amount: float) -> Item:
    # By default the buff increase the attack_speed if on_hit event occurs
    var buff_scene: PackedScene = load("res://src/Systems/Items/Buffs/buff.tscn")
    return ItemBuilder.make_buff_item(
        "Buff_%s_%s" % [stat_name, str(amount)],
        "Buff: +%s %s" % [amount, stat_name],
        stat_name,
        {"flat": amount},
        buff_scene
    )
