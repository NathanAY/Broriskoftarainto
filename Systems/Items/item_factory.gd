# item_factory.gd
extends Node
class_name ItemFactory

var rng := RandomNumberGenerator.new()

# empty at begining, fills by generated items.
var drop_pool: Array[Item] = []

@onready var stats: Stats = $Stats
# preload or lazy-load effect scenes
var effect_scenes: Array[PackedScene] = []


func _ready():
    _load_effect_scenes()

func _load_effect_scenes():
    var dir := DirAccess.open("res://Systems/Items/Modifiers")
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".tscn"):
                var path = "res://Systems/Items/Modifiers/%s" % file_name
                var scene = load(path)
                if scene is PackedScene:
                    effect_scenes.append(scene)
            file_name = dir.get_next()
        dir.list_dir_end()
    else:
        push_warning("Cannot open Modifiers folder!")

# -------------------
# Item Generation API
# -------------------
func get_item_from_pool_or_generate() -> Item:
    var pool_size = drop_pool.size()

    if pool_size == 0:
        var new_item = generate_random_item()
        drop_pool.append(new_item)
        return new_item

    # N/(N+1) chance from pool, 1/(N+1) chance generate new
    if rng.randi_range(0, pool_size) < pool_size:
        # take existing
        return drop_pool.pick_random()
    else:
        # generate new and push to pool
        var new_item = generate_random_item()
        drop_pool.append(new_item)
        return new_item

# -------------------
# Item Generators
# -------------------
func generate_random_item() -> Item:
    var stats_amount: int = stats.stats.size()
    var effect_amount: int = effect_scenes.size()
    var proportion: float = float(stats_amount) / (stats_amount + effect_amount)
    if rng.randf() < proportion:
        return _generate_stat_item()
    else:
        return _generate_effect_item()


func _generate_stat_item() -> Item:
    var stat_names = stats.stats.keys()
    if stat_names.is_empty():
        return null

    var chosen_stat = stat_names[rng.randi_range(0, stat_names.size() - 1)]
    var base_value = stats.stats[chosen_stat]

    var item := Item.new()
    item.name = _generate_item_name(chosen_stat)

    var value = {}
    # Percent-based stats (multiplicative scaling)
    if chosen_stat in ["attack_speed", "area_radius", "critical_multiplier"]:
        var flat_increase = rng.randf_range(0.05, 0.1) # 5–10%
        value["flat"] = float("%.2f" % [flat_increase])
    
    # Flat numeric stats
    elif base_value > 0:
        var flat_increase = base_value * rng.randf_range(0.05, 0.1) # 5–10% of base
        value["flat"] = float("%.2f" % [flat_increase])
    
    # Zero-based stats (e.g. armor, pierce, crit chance)
    else:
        value["flat"] = 1
    
    item.description = "Increases %s for %s" % [chosen_stat, value]
    item.modifiers[chosen_stat] = value
    return item

func _generate_effect_item() -> Item:
    var item := Item.new()
    var chosen_scene: PackedScene = effect_scenes[rng.randi_range(0, effect_scenes.size() - 1)]

    item.name = _generate_effect_name(chosen_scene.resource_path)
    item.description = "Grants special effect: %s" % item.name
    item.effect_scene = [chosen_scene]

    return item   

func _generate_item_name(stat: String) -> String:
    match stat:
        "health": return "Potion of Vitality"
        "movement_speed": return "Boots of Swiftness"
        "damage": return "Amulet of Power"
        "attack_speed": return "Gloves of Haste"
        "armor": return "Iron Skin"
        "critical_chance": return "Lucky Charm"
        _: return "Mystic " + stat.capitalize() + " Plus"

func _generate_effect_name(path: String) -> String:
    # crude but effective: use filename without extension
    var fname = path.get_file().get_basename()
    return fname.capitalize()
