extends Resource
class_name Item

@export var name: String
@export var description: String
@export var modifiers: Dictionary = {} # optional stat modifiers ex: {"damage": {"flat": 5}, "condition": "standing_still"}}
@export var effect_scene: Array [PackedScene] #optional, for special effects (explosions, spread shot, chain projectiles, crit)
@export var effect_scene_condition: Array[String] = [] # optional effect_scene condition. ex: "standing_still"
@export var condition_managers: Array[PackedScene] = [] # optional condition managers
## Rolled by `ItemFactory.apply_rarity()`. Hand-made `.tres` items stay COMMON.
@export var rarity: BaseWeapon.Rarity = BaseWeapon.Rarity.COMMON

## Fallbacks for the `item_rarity` block of `res://game_config.json`. Each list
## has one value per `BaseWeapon.Rarity`; what each means is in
## `docs/systems/game_config.md`.
const RARITY_DEFAULTS: Dictionary = {
    "weights": [60.0, 25.0, 10.0, 4.0, 1.0],
    "positive_multipliers": [1.0, 1.25, 1.5, 1.8, 2.2],
    "negative_multipliers": [1.0, 1.05, 1.1, 1.15, 1.25],
    "extra_positive_chance": [0.0, 0.35, 0.45, 0.55, 0.65],
    "extra_negative_chance": [0.2, 0.15, 0.1, 0.05, 0.02],
}

## The `key` list's entry for `item_rarity`, e.g. the legendary positive multiplier.
static func rarity_value(key: String, item_rarity: int) -> float:
    var values: Array = GameConfig.section("item_rarity").get(key, RARITY_DEFAULTS[key])
    return float(values[clampi(item_rarity, 0, values.size() - 1)])

# Apply modifiers / effects to a holder (holder = Node that has "Stats" child)
func apply_to(holder: Node) -> void:
    if not holder:
        return
    var stats_node: Stats = holder.get_node_or_null("Stats")
    if stats_node and modifiers:
        stats_node.add_modifier(modifiers)
        # Spawn condition managers
    for cm_scene in condition_managers:
        var cm = cm_scene.instantiate()
        stats_node.add_condition_manager(cm)    

# Remove modifiers
func remove_from(holder: Node) -> void:
    if not holder:
        return
    var stats_node = holder.get_node_or_null("Stats")
    if stats_node and modifiers:
        stats_node.remove_modifier(modifiers)
    #todo remove condition manager too
