# GdUnit generated TestSuite
class_name ItemCreationStatTest
extends GdUnitTestSuite

func test_stat_creation_stat() -> void:
    var factory : ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
    add_child(factory)
    var item = factory.get_item_by_type("stat")
    assert_object(item).is_not_null()
    collect_orphan_node_details()


func _make_factory(overrides: Dictionary) -> ItemFactory:
    var factory : ItemFactory = auto_free(load("res://src/Systems/Items/ItemFactory.tscn").instantiate())
    add_child(factory)
    factory.stat_overrides = overrides
    return factory


func test_min_roll_override_applies_to_any_stat() -> void:
    var factory := _make_factory({"armor": {"min_roll": 7.0}})
    for i in range(50):
        var roll := factory._generate_stat_modifiers("armor", 10.0)
        assert_float(float(roll["flat"])).is_greater_equal(7.0)


func test_stat_without_override_is_not_floored() -> void:
    var factory := _make_factory({"armor": {"min_roll": 7.0}})
    var roll := factory._generate_stat_modifiers("speed", 10.0)
    assert_float(float(roll["flat"])).is_less(7.0)


func test_pick_weight_override_makes_any_stat_more_common() -> void:
    var factory := _make_factory({"b": {"pick_weight": 4}, "c": {"pick_weight": 0}})
    var counts := {}
    for i in range(3000):
        var picked := factory._pick_stat_name(["a", "b", "c"])
        counts[picked] = counts.get(picked, 0) + 1
    assert_int(counts.get("c", 0)).is_equal(0)
    assert_float(float(counts["b"])).is_greater(float(counts["a"]) * 2.0)
