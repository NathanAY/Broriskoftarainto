# GdUnit generated TestSuite
class_name ItemCreationBuffTest
extends GdUnitTestSuite

func test_stat_creation_buff() -> void:
    var factory : ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
    add_child(factory)
    var item = factory.get_item_by_type("buff")
    assert_object(item).is_not_null()
    collect_orphan_node_details()
