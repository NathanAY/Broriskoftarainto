class_name ItemPickupTest
extends GdUnitTestSuite

func test_pickup_menu_shows_buff_details() -> void:
    var pickup = load("res://src/Systems/Items/item_pickup.gd").new()
    add_child(pickup)
    var factory: ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
    add_child(factory)
    var buff_item: Item = factory.get_item_by_type("buff")
    assert_object(buff_item).is_not_null()
    pickup.item = buff_item
    pickup.show_menu()
    var label: Label = pickup.interaction_menu.get_node("Description/Label")
    var expected: String = "\n".join(ItemTooltip.tooltip_lines(buff_item))
    assert_str(label.text).is_equal(expected)
    assert_bool("name: " in label.text).is_true()
    assert_bool("buff: " in label.text).is_true()
    assert_bool("tradeoff: " in label.text).is_true()
    collect_orphan_node_details()

func test_pickup_menu_shows_stat_details() -> void:
    var pickup = load("res://src/Systems/Items/item_pickup.gd").new()
    add_child(pickup)
    var factory: ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
    add_child(factory)
    var stat_item: Item = factory.get_item_by_type("stat")
    assert_object(stat_item).is_not_null()
    pickup.item = stat_item
    pickup.show_menu()
    var label: Label = pickup.interaction_menu.get_node("Description/Label")
    var expected: String = "\n".join(ItemTooltip.tooltip_lines(stat_item))
    assert_str(label.text).is_equal(expected)
    assert_bool("name: " in label.text).is_true()
    assert_bool(" flat: " in label.text).is_true()
    collect_orphan_node_details()