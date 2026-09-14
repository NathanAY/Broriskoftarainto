# GdUnit generated TestSuite
class_name ItemBuilderGdUnit4Test
extends GdUnitTestSuite

const BUFF_SCENE := "res://src/Systems/Items/Buffs/buff.tscn"
const DEBUFF_SCENE := "res://src/Systems/Items/Buffs/DebuffSource.tscn"
const EFFECT_SCENE := "res://src/Systems/Items/Modifiers/ProjectileBounceModifier.tscn"

func test_make_stat_item() -> void:
    var item: Item = ItemBuilder.make_stat_item("Sword", "Increases damage", {"damage": {"flat": 5}})
    assert_object(item).is_not_null()
    assert_that(item.name).is_equal("Sword")
    assert_that(item.description).is_equal("Increases damage")
    assert_that(item.modifiers).is_equal({"damage": {"flat": 5}})
    assert_int(item.effect_scene.size()).is_equal(0)

func test_make_effect_item() -> void:
    var scene: PackedScene = load(EFFECT_SCENE)
    assert_object(scene).is_not_null()
    var item: Item = ItemBuilder.make_effect_item("Bounce", "Grants effect", scene, {"damage": {"flat": -2}})
    assert_that(item.name).is_equal("Bounce")
    assert_that(item.description).is_equal("Grants effect")
    assert_int(item.effect_scene.size()).is_equal(1)
    assert_that(item.effect_scene[0]).is_same(scene)
    assert_that(item.modifiers).is_equal({"damage": {"flat": -2}})

func test_make_buff_item() -> void:
    var item: Item = ItemBuilder.make_buff_item("Buff", "Grants buff", "attack_speed", {"flat": 2.5}, load(BUFF_SCENE))
    assert_object(item).is_not_null()
    assert_that(item.get_meta("type")).is_equal("buff")
    assert_int(item.modifiers.size()).is_equal(0)
    assert_int(item.effect_scene.size()).is_equal(1)

    var buff: Buff = item.effect_scene[0].instantiate()
    assert_object(buff).is_not_null()
    assert_that(buff.modifiers).is_equal({"attack_speed": {"flat": 2.5}})
    collect_orphan_node_details()

func test_make_debuff_item() -> void:
    var item: Item = ItemBuilder.make_debuff_item("Debuff", "Grants debuff", "armor", {"flat": -10}, load(DEBUFF_SCENE))
    assert_object(item).is_not_null()
    assert_that(item.get_meta("type")).is_equal("debuff")
    assert_int(item.modifiers.size()).is_equal(0)
    assert_int(item.effect_scene.size()).is_equal(1)

    var debuff: DebuffSource = item.effect_scene[0].instantiate()
    assert_object(debuff).is_not_null()
    assert_that(debuff.modifiers).is_equal({"armor": {"flat": -10}})
    collect_orphan_node_details()

func test_pack_instance_preserves_config() -> void:
    var modifier: StatMultiplierModifier = preload("res://src/Systems/Items/Modifiers/stat_multiplier_modifier.gd").new()
    modifier.target_stat = "damage"
    modifier.multiplier = 2.5

    var packed: PackedScene = ItemBuilder.pack_instance(modifier)
    assert_object(packed).is_not_null()
    var inst: StatMultiplierModifier = packed.instantiate()
    assert_that(inst.target_stat).is_equal("damage")
    assert_that(inst.multiplier).is_equal(2.5)
    collect_orphan_node_details()

func test_load_scenes_from_dir_returns_packed_scenes() -> void:
    var scenes: Array[PackedScene] = ItemBuilder.load_scenes_from_dir("res://src/Systems/Items/Modifiers")
    assert_bool(scenes.size() > 0).is_true()
    for scene in scenes:
        assert_object(scene).is_not_null()
        assert_bool(scene is PackedScene).is_true()
