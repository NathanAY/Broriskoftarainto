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
    _load_scenes_from_dir("res://Systems/Items/Modifiers", effect_scenes)
    buff_scenes.append(load("res://Systems/Items/Buffs/buff.tscn"))
    debuff_scene = load("res://Systems/Items/Buffs/DebuffSource.tscn")


# -------------------
# Scene Loading
# -------------------   
func _load_scenes_from_dir(path: String, out_array: Array):
    var dir := DirAccess.open(path)
    if not dir:
        push_warning("Cannot open folder: " + path)
        return

    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
        if file_name.ends_with(".tscn"):
            var scene_path = "%s/%s" % [path, file_name]
            var scene = load(scene_path)
            if scene is PackedScene:
                out_array.append(scene)
        file_name = dir.get_next()
    dir.list_dir_end()


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
    var stat_threshold := float(stats_amount) / total
    var effect_threshold := float(stats_amount + effect_amount) / total

    return _generate_debuff_item()
    if roll < 0.4:
        return _generate_stat_item()
    elif roll < 0.7:
        return _generate_effect_item()
    elif roll < 0.85:
        return _generate_buff_item()
    elif roll < 1:
        return _generate_debuff_item()    

func _generate_stat_item() -> Item:
    var stat_names = stats.stats.keys()

    var chosen_stat = stat_names[rng.randi_range(0, stat_names.size() - 1)]
    var base_value = stats.stats[chosen_stat]
    var value = _generate_stat_modifiers(chosen_stat, base_value)
    
    var negative_chosen_stat = stat_names[rng.randi_range(0, stat_names.size() - 1)]
    var negative_base_value = stats.stats[negative_chosen_stat]
    var negative_value: Dictionary = _generate_stat_modifiers(negative_chosen_stat, negative_base_value)
    negative_value.set("flat", -negative_value.get("flat"))

    var item: Item = Item.new()
    item.name = _generate_item_name(chosen_stat)
    item.description = "Increases %s for %s\nDecreasese %s for %s" % [chosen_stat, value, negative_chosen_stat, negative_value]
    item.modifiers[chosen_stat] = value
    item.modifiers[negative_chosen_stat] = negative_value
    return item

func _generate_effect_item() -> Item:
    var item := Item.new()
    var chosen_scene: PackedScene = effect_scenes.pick_random()
    #var chosen_scene: PackedScene = effect_scenes.get(7)# 6 = explosive_shot, 7 = HealOnEvent
    
    item.name = _generate_effect_name(chosen_scene.resource_path)
    item.description = "Grants special effect: %s" % [item.name]

    # Try to configure dynamic parameters like trigger_event
    var configured_scene: PackedScene = _configure_dynamic_modifier(chosen_scene)
    var temp_instance = configured_scene.instantiate()
    var props := []
    for p in temp_instance.get_property_list():
        props.append(p.name)
    if "trigger_event" in props:
        var trig = temp_instance.get("trigger_event")
        if trig != null:
            item.description += " (Triggers on %s)" % str(trig).replace("_", " ")
    temp_instance.queue_free()
    
    #add negative effect
    var stat_names = stats.stats.keys()
    var negative_chosen_stat = stat_names[rng.randi_range(0, stat_names.size() - 1)]
    var negative_base_value = stats.stats[negative_chosen_stat]
    var negative_value: Dictionary = _generate_stat_modifiers(negative_chosen_stat, negative_base_value)
    negative_value.set("flat", -negative_value.get("flat") * 2)
    item.description += "\nDecreasese %s for %s" % [negative_chosen_stat, negative_value]
    item.modifiers[negative_chosen_stat] = negative_value

    item.effect_scene = [configured_scene]
    return item

func _generate_buff_item() -> Item:
    var stat_names = stats.stats.keys()

    # Choose a random Buff scene
    var chosen_scene: PackedScene = buff_scenes.pick_random()

    # Choose a random stat to affect
    var chosen_stat = stat_names[rng.randi_range(0, stat_names.size() - 1)]
    var base_value = stats.stats[chosen_stat]

    # Generate modifier value — same logic as stat items
    var modifier_value = _generate_stat_modifiers(chosen_stat, base_value)

    var negative_chosen_stat = stat_names[rng.randi_range(0, stat_names.size() - 1)]
    var negative_base_value = stats.stats[negative_chosen_stat]
    var negative_value: Dictionary = _generate_stat_modifiers(negative_chosen_stat, negative_base_value)
    negative_value.set("flat", -negative_value.get("flat"))

    # Create item resource
    var item := Item.new()
    item.name = _generate_buff_name(chosen_scene.resource_path, chosen_stat)
    item.description = "Grants a temporary buff: increases %s when triggered." % [chosen_stat]
    item.description += "\nDecreasese %s for %s" % [negative_chosen_stat, negative_value]
    item.effect_scene = [chosen_scene]
    item.modifiers[negative_chosen_stat] = negative_value

    item.set_meta("type", "buff")

    # 💡 Create a Buff instance to inject dynamic modifiers
    var buff_instance: Buff = chosen_scene.instantiate()
    buff_instance.modifiers = {chosen_stat: modifier_value}
    buff_instance.name = item.name

    # Store it as a pre-configured scene (ready to instance)
    var packed = PackedScene.new()
    packed.pack(buff_instance)
    item.effect_scene = [packed]
    return item

func _generate_debuff_item() -> Item:
    var stat_names = stats.stats.keys()

    # Choose a random Buff scene
    var chosen_scene: PackedScene = debuff_scene

    # Choose a random stat to affect
    var chosen_stat = stat_names[rng.randi_range(0, stat_names.size() - 1)]
    var base_value = stats.stats[chosen_stat]

    # Generate modifier value — same logic as stat items and invert for debuff
    var modifier_value: Dictionary = _generate_stat_modifiers(chosen_stat, base_value)
    var value: float  = modifier_value.get("flat");
    modifier_value.set("flat", -value)

    # Create item resource
    var item := Item.new()
    item.name = _generate_buff_name(chosen_scene.resource_path, chosen_stat)
    item.description = "Grants a debuff: decreases %s when triggered." % chosen_stat
    item.effect_scene = [chosen_scene]
    item.set_meta("type", "debuff")

    # Add negative effect
    var negative_chosen_stat = stat_names[rng.randi_range(0, stat_names.size() - 1)]
    var negative_base_value = stats.stats[negative_chosen_stat]
    var negative_value: Dictionary = _generate_stat_modifiers(negative_chosen_stat, negative_base_value)
    negative_value.set("flat", -negative_value.get("flat") * 2)
    item.description += "\nDecreasese %s for %s" % [negative_chosen_stat, negative_value]
    item.modifiers[negative_chosen_stat] = negative_value

    # 💡 Create a Buff instance to inject dynamic modifiers
    var buff_instance: DebuffSource = chosen_scene.instantiate()
    buff_instance.modifiers = {chosen_stat: modifier_value}
    buff_instance.name = item.name

    # Store it as a pre-configured scene (ready to instance)
    var packed = PackedScene.new()
    packed.pack(buff_instance)
    item.effect_scene = [packed]
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
    var packed := PackedScene.new()
    packed.pack(instance)
    return packed

func _generate_stat_modifiers(chosen_stat, base_value) -> Dictionary:
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
