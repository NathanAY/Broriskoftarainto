extends GutTest

func test_item_damage_doubler():
    var test_scene = load("res://test/TestScene.tscn").instantiate()
    get_tree().root.add_child(test_scene)

    var character: Character = test_scene.get_node("Character")
    var c_stats: Stats = character.get_node_or_null("Stats")
    var c_item_holder: ItemHolder = character.get_node_or_null("ItemHolder")
    var _c_health: Health = character.get_node("Health")
    
    # 1. Setup Items
    var doubler_item = ItemBuilder.make_effect_item("Damage Doubler", "", _pack_doubler("damage", 2.0))
    
    var damage_item = ItemBuilder.make_stat_item("Damage Up", "", {"damage": {"flat": 10.0}})
    var enemy: Enemy = test_scene.get_node("Enemy")
    var e_stats: Stats = enemy.get_node_or_null("Stats")
    var e_health: Health = enemy.get_node("Health")
    
    e_stats.set_base_stat("health", e_stats.stats["health"] + 100000)
    e_health.heal(100000)
    
    var final_damage = c_stats.get_stat("damage")
    assert_eq(final_damage, 1.0)

    # 2. Add Items
    # await wait_seconds(2)
    c_item_holder.add_item(doubler_item)
    final_damage = c_stats.get_stat("damage")
    assert_eq(final_damage, 1.0)
    # await wait_seconds(2)
    
    c_item_holder.add_item(damage_item)
    # 3. Verify Stats
    # Assuming stats.get_stat("damage") reflects applied modifiers
    final_damage = c_stats.get_stat("damage")
    assert_eq(final_damage, 21.0)
    # await wait_seconds(2)
    test_scene.queue_free()

func test_item_health_50_percent_bonus():
    var test_scene = load("res://test/TestScene.tscn").instantiate()
    get_tree().root.add_child(test_scene)

    var character: Character = test_scene.get_node("Character")
    var c_stats: Stats = character.get_node_or_null("Stats")
    var c_item_holder: ItemHolder = character.get_node_or_null("ItemHolder")
    var _c_health: Health = character.get_node("Health")
    
    # 1. Setup Items
    var doubler_item = ItemBuilder.make_effect_item("Helathier", "", _pack_doubler("health", 1.5))
    
    var stat_item = ItemBuilder.make_stat_item("Health Up", "", {"health": {"flat": 100.0}})
    
    var enemy: Enemy = test_scene.get_node("Enemy")
    var e_stats: Stats = enemy.get_node_or_null("Stats")
    var e_health: Health = enemy.get_node("Health")
    
    e_stats.set_base_stat("health", e_stats.stats["health"] + 100000)
    e_health.heal(100000)
    
    var stat_value = c_stats.get_stat("health")
    assert_eq(stat_value, 1040.0)
    
     # 2. Add Items
    # await wait_seconds(2)
    c_item_holder.add_item(doubler_item)
    stat_value = c_stats.get_stat("health")
    assert_eq(stat_value, 1040.0)
    # await wait_seconds(2)

    c_item_holder.add_item(stat_item)
    # 3. Verify Stats
    # Assuming stats.get_stat("damage") reflects applied modifiers
    stat_value = c_stats.get_stat("health")
    assert_eq(stat_value, 1190.0)
    # await wait_seconds(2)
    test_scene.queue_free()

func _pack_doubler(target_stat: String, multiplier: float) -> PackedScene:
    var doubler_mod = preload("res://src/Systems/Items/modifiers/stat_multiplier_modifier.gd").new()
    doubler_mod.target_stat = target_stat
    doubler_mod.multiplier = multiplier
    return ItemBuilder.pack_instance(doubler_mod)
