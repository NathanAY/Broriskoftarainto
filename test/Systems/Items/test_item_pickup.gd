class_name ItemPickupTest
extends GdUnitTestSuite

## Pinned so the assertions below describe a fixed item. The factory draws from
## `rng`, and whether an item's curse is a negated stat or a harmful modifier is
## a roll - an unpinned factory made this suite pass or fail run to run.
const SEED: int = 20260930

func _factory() -> ItemFactory:
    var factory: ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
    add_child(factory)
    factory.rng.seed = SEED
    return factory

func test_pickup_menu_shows_buff_details() -> void:
    var pickup = load("res://src/Systems/Items/item_pickup.gd").new()
    add_child(pickup)
    var buff_item: Item = _factory().get_item_by_type("buff")
    assert_object(buff_item).is_not_null()
    pickup.item = buff_item
    pickup.show_menu()
    var label: Label = pickup.interaction_menu.get_node("Description/Label")
    var expected: String = "\n".join(ItemTooltip.tooltip_lines(buff_item))
    assert_str(label.text).is_equal(expected)
    assert_bool("name: " in label.text).is_true()
    assert_bool("buff: " in label.text).is_true()
    # A generated item is always a gift and a curse. The curse is either a
    # negated stat (a "tradeoff:" line) or a harmful modifier (an "effect:" line),
    # so it must be one or the other, never neither.
    assert_bool("tradeoff: " in label.text or "effect: " in label.text).is_true()
    collect_orphan_node_details()

func test_pickup_menu_shows_stat_details() -> void:
    var pickup = load("res://src/Systems/Items/item_pickup.gd").new()
    add_child(pickup)
    var stat_item: Item = _factory().get_item_by_type("stat")
    assert_object(stat_item).is_not_null()
    pickup.item = stat_item
    pickup.show_menu()
    var label: Label = pickup.interaction_menu.get_node("Description/Label")
    var expected: String = "\n".join(ItemTooltip.tooltip_lines(stat_item))
    assert_str(label.text).is_equal(expected)
    assert_bool("name: " in label.text).is_true()
    assert_bool(" flat: " in label.text).is_true()
    collect_orphan_node_details()
