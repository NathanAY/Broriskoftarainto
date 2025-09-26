# item_factory.gd
extends Node
class_name ItemFactory

var rng := RandomNumberGenerator.new()

@onready var stats: Stats = $Stats

# pass in a Stats instance (so we can use its current values)
func generate_random_item() -> Item:
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

func _generate_item_name(stat: String) -> String:
    match stat:
        "health": return "Potion of Vitality"
        "movement_speed": return "Boots of Swiftness"
        "damage": return "Amulet of Power"
        "attack_speed": return "Gloves of Haste"
        "armor": return "Iron Skin"
        "critical_chance": return "Lucky Charm"
        _: return "Mystic " + stat.capitalize() + " Plus"
