# GdUnit generated TestSuite
class_name ItemFactoryGdUnit4Test
extends GdUnitTestSuite

# Test suite for ItemFactory
func test_stat_creation_stat() -> void:
    var factory = ItemFactory.new()
    factory._ready()
    factory.stats = Stats.new()
    var item = factory.get_item_by_type("stat")
    assert_object(item).is_not_null()

func test_stat_creation_effect() -> void:
    var factory = ItemFactory.new()
    factory._ready()
    factory.stats = Stats.new()
    var item = factory.get_item_by_type("effect")
    assert_object(item).is_not_null()

func test_stat_creation_buff() -> void:
    var factory = ItemFactory.new()
    factory._ready()
    factory.stats = Stats.new()
    var item = factory.get_item_by_type("buff")
    assert_object(item).is_not_null()

func test_stat_creation_debuff() -> void:
    var factory = ItemFactory.new()
    factory._ready()
    factory.stats = Stats.new()
    var item = factory.get_item_by_type("debuff")
    assert_object(item).is_not_null()
