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
    _load_effect_scenes()
    buff_scenes.append(load("res://Systems/Items/Buffs/buff.tscn"))
    debuff_scene = load("res://Systems/Items/Buffs/DebuffSource.tscn")


# -------------------
# Scene Loading
# -------------------
func _load_effect_scenes():
    _load_scenes_from_dir("res://Systems/Items/Modifiers", effect_scenes)

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

    return _generate_debuff_item()#TODO : remove
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
    if stat_names.is_empty():
        return null

    var chosen_stat = stat_names[rng.randi_range(0, stat_names.size() - 1)]
    var base_value = stats.stats[chosen_stat]
    var value = _generate_stat_modifiers(chosen_stat, base_value)

    var item := Item.new()
    item.name = _generate_item_name(chosen_stat)
    item.description = "Increases %s for %s" % [chosen_stat, value]
    item.modifiers[chosen_stat] = value
    return item


func _generate_effect_item() -> Item:
    if effect_scenes.is_empty():
        return null
    var item := Item.new()
    var chosen_scene: PackedScene = effect_scenes.pick_random()

    item.name = _generate_effect_name(chosen_scene.resource_path)
    item.description = "Grants special effect: %s" % item.name
    item.effect_scene = [chosen_scene]
    return item


func _generate_buff_item() -> Item:
    if buff_scenes.is_empty():
        return null

    var stat_names = stats.stats.keys()
    if stat_names.is_empty():
        return null

    # Choose a random Buff scene
    var chosen_scene: PackedScene = buff_scenes.pick_random()

    # Choose a random stat to affect
    var chosen_stat = stat_names[rng.randi_range(0, stat_names.size() - 1)]
    var base_value = stats.stats[chosen_stat]

    # Generate modifier value — same logic as stat items
    var modifier_value = _generate_stat_modifiers(chosen_stat, base_value)

    # Create item resource
    var item := Item.new()
    item.name = _generate_buff_name(chosen_scene.resource_path, chosen_stat)
    item.description = "Grants a temporary buff: increases %s when triggered." % chosen_stat
    item.effect_scene = [chosen_scene]
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
    if stat_names.is_empty():
        return null

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
