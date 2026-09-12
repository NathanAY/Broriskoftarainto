class_name ItemSacrificeAltarGdUnit4Test
extends GdUnitTestSuite

func test_add_item_keeps_item_references() -> void:
    var altar = ItemSacrificeAltar.new()
    var item = Item.new()
    item.name = "Test Item"
    altar.add_item(item)
    assert_object(altar.altar_item).is_not_null()
    altar.free()
