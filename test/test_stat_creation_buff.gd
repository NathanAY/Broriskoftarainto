# GdUnit generated TestSuite
class_name StatCreationBuffTest
extends GdUnitTestSuite

func test_stat_creation_buff() -> void:
    var factory = ItemFactory.new()
    factory._ready()
    factory.stats = Stats.new()
    var item = factory.get_item_by_type("buff")
    assert_object(item).is_not_null()
