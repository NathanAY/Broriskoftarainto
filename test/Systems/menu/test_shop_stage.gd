# GdUnit generated TestSuite
class_name ShopStageTest
extends GdUnitTestSuite


func test_shop_stage_opens_shop_automatically() -> void:
    var runner := scene_runner("res://test/TestShopStage.tscn")
    var test_scene := runner.scene()
    get_tree().current_scene = test_scene

    await runner.simulate_frames(10)

    var shop_menu: ShopMenu = test_scene.get_node("UI/ShopMenu")
    assert_bool(shop_menu.visible).is_true()
    assert_int(shop_menu.phase).is_equal(2)
    assert_bool(shop_menu.item_factory != null).is_true()
    # Shop phase generates 4 purchasable entries.
    assert_int(shop_menu.items_container.get_child_count()).is_equal(4)
    # Starting money is granted so buy/reroll work immediately.
    var character: Character = test_scene.get_node("Character")
    assert_object(GlobalGameState.current_character).is_equal(character)
    assert_float(character.get_node("Stats").stats.get("money", 0.0)).is_equal(100.0)

    get_tree().paused = false
    test_scene.free()
