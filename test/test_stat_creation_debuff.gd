# GdUnit generated TestSuite
class_name StatCreationDebuffTest
extends GdUnitTestSuite

func test_stat_creation_debuff() -> void:
    var factory = ItemFactory.new()
    factory._ready()
    factory.stats = Stats.new()
    var item = factory.get_item_by_type("debuff")
    assert_object(item).is_not_null()
