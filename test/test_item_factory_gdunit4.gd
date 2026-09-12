# GdUnit generated TestSuite
class_name ItemFactoryGdUnit4Test
extends GdUnitTestSuite

# Test suite for ItemFactory
func test_stat_creation_stat() -> void:
    var factory : ItemFactory = load("res://Systems/Items/ItemFactory.tscn").instantiate()
    add_child(factory)
    var item = factory.get_item_by_type("stat")
    assert_object(item).is_not_null()
    collect_orphan_node_details()

func test_stat_creation_effect() -> void:
    var factory : ItemFactory = load("res://Systems/Items/ItemFactory.tscn").instantiate()
    add_child(factory)
    var item = factory.get_item_by_type("effect")
    assert_object(item).is_not_null()
    collect_orphan_node_details()

func test_stat_creation_buff() -> void:
    var factory : ItemFactory = load("res://Systems/Items/ItemFactory.tscn").instantiate()
    add_child(factory)
    var item = factory.get_item_by_type("buff")
    assert_object(item).is_not_null()
    collect_orphan_node_details()

func test_stat_creation_debuff() -> void:
    var factory : ItemFactory = load("res://Systems/Items/ItemFactory.tscn").instantiate()
    add_child(factory)
    var item = factory.get_item_by_type("debuff")
    assert_object(item).is_not_null()
    collect_orphan_node_details()
