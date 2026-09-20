# GdUnit generated TestSuite
class_name ItemFactoryGdUnit4Test
extends GdUnitTestSuite

# Test suite for ItemFactory
func test_stat_creation_stat() -> void:
    var factory : ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
    add_child(factory)
    var item = factory.get_item_by_type("stat")
    assert_object(item).is_not_null()
    collect_orphan_node_details()

func test_stat_creation_effect() -> void:
    var factory : ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
    add_child(factory)
    var item = factory.get_item_by_type("effect")
    assert_object(item).is_not_null()
    collect_orphan_node_details()

func test_stat_creation_buff() -> void:
    var factory : ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
    add_child(factory)
    var item = factory.get_item_by_type("buff")
    assert_object(item).is_not_null()
    collect_orphan_node_details()

func test_stat_creation_debuff() -> void:
    var factory : ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
    add_child(factory)
    var item = factory.get_item_by_type("debuff")
    assert_object(item).is_not_null()
    collect_orphan_node_details()

func test_buff_description_names_actual_trigger() -> void:
    var factory : ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
    add_child(factory)
    var item: Item = factory.get_item_by_type("buff")
    assert_object(item).is_not_null()
    assert_bool("when triggered" in item.description).is_false()
    assert_bool("Triggers on" in item.description).is_true()
    var trigger := ItemTooltip.peek_packed_trigger(item.effect_scene[0])
    assert_bool(trigger.is_empty()).is_false()
    assert_bool(ItemTooltip.humanize_trigger(trigger) in item.description).is_true()
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    for line in lines:
        assert_bool("when triggered" in line).is_false()
    collect_orphan_node_details()

func test_debuff_description_names_actual_trigger() -> void:
    var factory : ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
    add_child(factory)
    var item: Item = factory.get_item_by_type("debuff")
    assert_object(item).is_not_null()
    assert_bool("when triggered" in item.description).is_false()
    assert_bool("Triggers on" in item.description).is_true()
    var trigger := ItemTooltip.peek_packed_trigger(item.effect_scene[0])
    assert_bool(trigger.is_empty()).is_false()
    assert_bool(ItemTooltip.humanize_trigger(trigger) in item.description).is_true()
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    for line in lines:
        assert_bool("when triggered" in line).is_false()
    collect_orphan_node_details()
