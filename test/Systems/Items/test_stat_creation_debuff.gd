# GdUnit generated TestSuite
class_name StatCreationDebuffTest
extends GdUnitTestSuite

func test_stat_creation_debuff() -> void:
    var factory : ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
    add_child(factory)
    var item = factory.get_item_by_type("debuff")
    assert_object(item).is_not_null()
    collect_orphan_node_details()
