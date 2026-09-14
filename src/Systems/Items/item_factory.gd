extends Node
class_name ItemFactory

var rng := RandomNumberGenerator.new()

# empty at begining, fills by generated items.
var drop_pool: Array[Item] = []

@onready var stats: Stats = $Stats

# preload or lazy-load effect/buff scenes
var effect_scenes: Array[PackedScene] = []
var buff_scenes: Array[PackedScene] = []
var debuff_scene: PackedScene = null

func _ready():
    effect_scenes = ItemBuilder.load_scenes_from_dir("res://src/Systems/Items/Modifiers")
    buff_scenes.append(load("res://src/Systems/Items/Buffs/buff.tscn"))
    debuff_scene = load("res://src/Systems/Items/Buffs/DebuffSource.tscn")


# -------------------
# Item Generation API
# -------------------
func get_item_from_pool_or_generate() -> Item:
    var pool_size = drop_pool.size()

    if pool_size == 0:
        var new_item = generate_random_item()
        drop_pool.append(new_item)
        return new_item

    if rng.randi_range(0, pool_size) < pool_size:
        return drop_pool.pick_random()
    else:
        var new_item = generate_random_item()
        drop_pool.append(new_item)
        return new_item

func get_item_by_type(type: String, index: int = -1) -> Item:
    match type:
        "stat": return _generate_stat_item(index)
        "effect": return _generate_effect_item(index)
        "buff": return _generate_buff_item(index)
        "debuff": return _generate_debuff_item(index)
    return null

# -------------------
# Item Generators
# -------------------
func generate_random_item() -> Item:
    var stats_amount: int = stats.stats.size()
    var effect_amount: int = effect_scenes.size()
    var buff_amount: int = stats_amount
    var debuff_amount: int = stats_amount

    var total := stats_amount + effect_amount + buff_amount + debuff_amount
    if total == 0:
        push_warning("ItemFactory: no sources to generate items!")
        return null

    var roll := rng.randf()

    if roll < 0.4:
        return _generate_stat_item()
    elif roll < 0.7:
        return _generate_effect_item()
    elif roll < 0.85:
        return _generate_buff_item()
    elif roll < 1:
        return _generate_debuff_item()
    return _generate_debuff_item()

func _generate_stat_item(index: int = -1) -> Item:
    var stat_names = stats.stats.keys()
    var index_to_use = index if index != -1 else rng.randi_range(0, stat_names.size() - 1)
    var chosen_stat = stat_names[index_to_use]
    var base_value = stats.stats[chosen_stat]
    var value = _generate_stat_modifiers(chosen_stat, base_value)

    var negative_chosen_stat = stat_names[rng.randi_range(0, stat_names.size() - 1)]
    var negative_base_value = stats.stats[negative_chosen_stat]
    var negative_value: Dictionary = _generate_stat_modifiers(negative_chosen_stat, negative_base_value)
    negative_value.set("flat", -negative_value.get("flat"))

    return ItemBuilder.make_stat_item(
        _generate_item_name(chosen_stat),
        "Increases %s for %s\nDecreasese %s for %s" % [chosen_stat, value, negative_chosen_stat, negative_value],
        {chosen_stat: value, negative_chosen_stat: negative_value}
    )

func _generate_effect_item(index: int = -1) -> Item:
    var chosen_scene: PackedScene
    if index != -1:
        chosen_scene = effect_scenes[index]
    else:
        chosen_scene = effect_scenes.pick_random()

    var item_name = _generate_effect_name(chosen_scene.resource_path)
    var description := "Grants special effect: %s" % [item_name]

    # Try to configure dynamic parameters like trigger_event
    var configured_scene: PackedScene = _configure_dynamic_modifier(chosen_scene)
    var temp_instance = configured_scene.instantiate()
    var props := []
    for p in temp_instance.get_property_list():
        props.append(p.name)
    if "trigger_event" in props:
        var trig = temp_instance.get("trigger_event")
        if trig != null:
            description += " (Triggers on %s)" % str(trig).replace("_", " ")
    temp_instance.queue_free()

    #add negative effect
    var stat_names = stats.stats.keys()
    var negative_chosen_stat = stat_names[rng.randi_range(0, stat_names.size() - 1)]
    var negative_base_value = stats.stats[negative_chosen_stat]
    var negative_value: Dictionary = _generate_stat_modifiers(negative_chosen_stat, negative_base_value)
    negative_value.set("flat", -negative_value.get("flat") * 2)
    description += "\nDecreasese %s for %s" % [negative_chosen_stat, negative_value]

    return ItemBuilder.make_effect_item(
        item_name,
        description,
        configured_scene,
        {negative_chosen_stat: negative_value}
    )

func _generate_buff_item(index: int = -1) -> Item:
    var stat_names = stats.stats.keys()

    var chosen_scene: PackedScene
    if index != -1:
        chosen_scene = buff_scenes[index]
    else:
        chosen_scene = buff_scenes.pick_random()

    var chosen_stat = stat_names[rng.randi_range(0, stat_names.size() - 1)]
    var base_value = stats.stats[chosen_stat]
    var modifier_value = _generate_stat_modifiers(chosen_stat, base_value)

    var negative_chosen_stat = stat_names[rng.randi_range(0, stat_names.size() - 1)]
    var negative_base_value = stats.stats[negative_chosen_stat]
    var negative_value: Dictionary = _generate_stat_modifiers(negative_chosen_stat, negative_base_value)
    negative_value.set("flat", -negative_value.get("flat"))

    var item_name = _generate_buff_name(chosen_scene.resource_path, chosen_stat)
    var description := "Grants a temporary buff: increases %s when triggered." % [chosen_stat]
    description += "\nDecreasese %s for %s" % [negative_chosen_stat, negative_value]

    var item := ItemBuilder.make_buff_item(item_name, description, chosen_stat, modifier_value, chosen_scene)
    item.modifiers[negative_chosen_stat] = negative_value
    return item

func _generate_debuff_item(_index: int = -1) -> Item:
    var stat_names = stats.stats.keys()
    var chosen_scene: PackedScene = debuff_scene

    var chosen_stat = stat_names[rng.randi_range(0, stat_names.size() - 1)]
    var base_value = stats.stats[chosen_stat]
    var modifier_value: Dictionary = _generate_stat_modifiers(chosen_stat, base_value)
    var value: float = modifier_value.get("flat")
    modifier_value.set("flat", -value)

    var item_name = _generate_buff_name(chosen_scene.resource_path, chosen_stat)
    var description := "Grants a debuff: decreases %s when triggered." % [chosen_stat]

    var negative_chosen_stat = stat_names[rng.randi_range(0, stat_names.size() - 1)]
    var negative_base_value = stats.stats[negative_chosen_stat]
    var negative_value: Dictionary = _generate_stat_modifiers(negative_chosen_stat, negative_base_value)
    negative_value.set("flat", -negative_value.get("flat") * 2)
    description += "\nDecreasese %s for %s" % [negative_chosen_stat, negative_value]

    var item := ItemBuilder.make_debuff_item(item_name, description, chosen_stat, modifier_value, chosen_scene)
    item.modifiers[negative_chosen_stat] = negative_value
    return item

# -------------------
# Name Helpers
# -------------------
func _generate_item_name(stat: String) -> String:
    match stat:
        "health": return "Potion of Vitality"
        "movement_speed": return "Boots of Swiftness"
        "damage": return "Amulet of Power"
        "attack_speed": return "Gloves of Haste"
        "armor": return "Iron Skin"
        "critical_chance": return "Lucky Charm"
        _: return "Mystic " + stat.capitalize() + " Plus"

func _configure_dynamic_modifier(scene: PackedScene) -> PackedScene:
    var instance = scene.instantiate()

    # gather property names safely
    var props: Array = []
    for p in instance.get_property_list():
        props.append(p.name)

    # Only proceed if possible_trigger_event exists and is a Dictionary
    if "possible_trigger_event" in props and typeof(instance.get("possible_trigger_event")) == TYPE_DICTIONARY:
        var possible: Dictionary = instance.get("possible_trigger_event")
        var event_names: Array = possible.keys()
        var chosen_event: String = event_names.pick_random()
        # set trigger_event if that property exists
        if "trigger_event" in props:
            instance.set("trigger_event", chosen_event)

        # Apply overrides (only set properties that exist)
        var overrides: Dictionary = possible[chosen_event]
        for key in overrides.keys():
            if key in props:
                instance.set(key, overrides[key])
                print("Configured:", scene.resource_path, "->", key, "=", overrides[key], "(for event:", chosen_event, ")")
            else:
                print("Skipping override:", key, " — property not found on", scene.resource_path)
    else:
        return scene
    # Future: easily extend this logic to support other dynamic fields
    # e.g., if instance.has_variable("damage_bonus"), randomize range
    # Repack it as new scene
    return ItemBuilder.pack_instance(instance)

func _generate_stat_modifiers(_chosen_stat, base_value) -> Dictionary:
    var modifier_value = {}
    if base_value == 0:
        modifier_value["flat"] = 1
    elif base_value == 1:
        modifier_value["flat"] = float("%.2f" % [base_value * rng.randf_range(0.05, 0.1)])
    else:# Like 40
        modifier_value["flat"] = float("%.2f" % [base_value * rng.randf_range(0.05, 0.1)])
    return modifier_value

func _generate_effect_name(path: String) -> String:
    var fname = path.get_file().get_basename()
    return fname.capitalize()

func _generate_buff_name(path: String, stat_name: String) -> String:
    var fname = path.get_file().get_basename()
    return fname.capitalize() + " " + stat_name