extends GutTest

func test_item_factory():
    var test_scene = load("res://test/SceneWithItemFactory.tscn").instantiate()
    get_tree().root.add_child(test_scene)

    var item_factory: ItemFactory = test_scene.get_node("ItemFactory")
    var character: Character = test_scene.get_node("Character")
    var _c_stats: Stats = character.get_node_or_null("Stats")
    var _c_item_holder: ItemHolder = character.get_node_or_null("ItemHolder")
    var _c_health: Health = character.get_node("Health")
    
    var random_items: Array[Item] = []
    for i in 100:
        var random_item: Item = item_factory.generate_random_item()
        random_items.append(random_item)
    assert_eq(random_items.size(), 100)
    test_scene.queue_free()

func test_item_with_3_stats_has_3_image():
    var test_scene = load("res://test/SceneWithItemFactory.tscn").instantiate()
    get_tree().root.add_child(test_scene)

    var _item_factory: ItemFactory = test_scene.get_node("ItemFactory")
    var character: Character = test_scene.get_node("Character")
    var c_stats: Stats = character.get_node_or_null("Stats")
    var c_item_holder: ItemHolder = character.get_node_or_null("ItemHolder")
    var _c_health: Health = character.get_node("Health")

    var stat_item = ItemBuilder.make_stat_item("5 stat Up", "", {
        "health": {"flat": 100.0},
        "damage": {"flat": 100.0},
        "armor": {"flat": 100.0},
        "critical_chance": {"flat": 100.0},
        "movement_speed": {"flat": 100.0}
    })
    c_item_holder.add_item(stat_item)
    
    var _items_list: VBoxContainer = test_scene.get_node("UI/PauseMenu/CharacterUi/VBoxContainer/WeaponsAndItemsContainer/LeftContainer/LeftHBox/ItemsScroll/ItemsList")
    var critical_chance = c_stats.get_stat("critical_chance")
    await wait_seconds(0.5)
    assert_eq(critical_chance, 100.0)
    test_scene.queue_free()
