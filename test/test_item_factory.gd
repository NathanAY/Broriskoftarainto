extends GutTest

func test_item_factory():
    var test_scene = load("res://test/SceneWithItemFactory.tscn").instantiate()
    get_tree().root.add_child(test_scene)

    var item_factory: ItemFactory = test_scene.get_node("ItemFactory")
    var character: Character = test_scene.get_node("Character")
    var c_stats: Stats = character.get_node_or_null("Stats")
    var c_item_holder: ItemHolder = character.get_node_or_null("ItemHolder")
    var c_health: Health = character.get_node("Health")
    
    var random_items: Array[Item] = []
    for i in 100:
        var random_item: Item = item_factory.generate_random_item()
        random_items.append(random_item)
        

    assert_eq(random_items.size(), 100)
    test_scene.queue_free()
