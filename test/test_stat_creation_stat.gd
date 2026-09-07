# GdUnit generated TestSuite
class_name StatCreationStatTest
extends GdUnitTestSuite

func test_stat_creation_stat() -> void:
    var factory = ItemFactory.new()
    factory._ready()
    factory.stats = Stats.new()
    var item = factory.get_item_by_type("stat")
    assert_object(item).is_not_null()
    collect_orphan_node_details()
