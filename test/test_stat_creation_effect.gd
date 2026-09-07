# GdUnit generated TestSuite
class_name StatCreationEffectTest
extends GdUnitTestSuite

func test_stat_creation_effect() -> void:
    var factory = ItemFactory.new()
    factory._ready()
    factory.stats = Stats.new()
    var item = factory.get_item_by_type("effect")
    assert_object(item).is_not_null()
