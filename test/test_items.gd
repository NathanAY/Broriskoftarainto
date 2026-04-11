extends GutTest

func test_item_damage_doubler():
    var test_scene = load("res://test/TestScene.tscn").instantiate()
    get_tree().root.add_child(test_scene)

    var character: Character = test_scene.get_node("Character")
    var c_stats: Stats = character.get_node_or_null("Stats")
    var c_item_holder: ItemHolder = character.get_node_or_null("ItemHolder")
    var c_health: Health = character.get_node("Health")
    
    # 1. Setup Items
    var doubler_item = Item.new()
    doubler_item.name = "Damage Doubler"
    var doubler_mod = preload("res://Systems/Items/Modifiers/stat_multiplier_modifier.gd").new()
    # Configure the multiplier
    doubler_mod.target_stat = "damage"
    doubler_mod.multiplier = 2.0
    # Assuming Items can hold modifiers in effect_scene or a similar way as described in architecture
    var packed = PackedScene.new()
    packed.pack(doubler_mod)
    doubler_item.effect_scene.append(packed)
    
    var damage_item = Item.new()
    damage_item.name = "Damage Up"
    damage_item.modifiers["damage"] = {"flat": 10.0}
    
    var enemy: Enemy = test_scene.get_node("Enemy")
    var e_stats: Stats = enemy.get_node_or_null("Stats")
    var e_health: Health = enemy.get_node("Health")
    
    e_stats.set_base_stat("health", e_stats.stats["health"] + 100000)
    e_health.heal(100000)
    
    var final_damage = c_stats.get_stat("damage")
    assert_eq(final_damage, 1)

    # 2. Add Items
    # await wait_seconds(2)
    c_item_holder.add_item(doubler_item)
    final_damage = c_stats.get_stat("damage")
    assert_eq(final_damage, 1)
    # await wait_seconds(2)
    
    c_item_holder.add_item(damage_item)
    # 3. Verify Stats
    # Assuming stats.get_stat("damage") reflects applied modifiers
    final_damage = c_stats.get_stat("damage")
    assert_eq(final_damage, 21)
    # await wait_seconds(2)

func test_item_health_50_percent_bonus():
    var test_scene = load("res://test/TestScene.tscn").instantiate()
    get_tree().root.add_child(test_scene)

    var character: Character = test_scene.get_node("Character")
    var c_stats: Stats = character.get_node_or_null("Stats")
    var c_item_holder: ItemHolder = character.get_node_or_null("ItemHolder")
    var c_health: Health = character.get_node("Health")
    
    # 1. Setup Items
    var doubler_item = Item.new()
    doubler_item.name = "Helathier"
    var doubler_mod = preload("res://Systems/Items/Modifiers/stat_multiplier_modifier.gd").new()
    # Configure the multiplier
    doubler_mod.target_stat = "health"
    doubler_mod.multiplier = 1.5
    # Assuming Items can hold modifiers in effect_scene or a similar way as described in architecture
    var packed = PackedScene.new()
    packed.pack(doubler_mod)
    doubler_item.effect_scene.append(packed)
    
    var stat_item = Item.new()
    stat_item.name = "Health Up"
    stat_item.modifiers["health"] = {"flat": 100.0}
    
    var enemy: Enemy = test_scene.get_node("Enemy")
    var e_stats: Stats = enemy.get_node_or_null("Stats")
    var e_health: Health = enemy.get_node("Health")
    
    e_stats.set_base_stat("health", e_stats.stats["health"] + 100000)
    e_health.heal(100000)
    
    var stat_value = c_stats.get_stat("health")
    assert_eq(stat_value, 2040)

    # 2. Add Items
    # await wait_seconds(2)
    c_item_holder.add_item(doubler_item)
    stat_value = c_stats.get_stat("health")
    assert_eq(stat_value, 2040)
    # await wait_seconds(2)
    
    c_item_holder.add_item(stat_item)
    # 3. Verify Stats
    # Assuming stats.get_stat("damage") reflects applied modifiers
    stat_value = c_stats.get_stat("health")
    assert_eq(stat_value, 2190)
    # await wait_seconds(2)
