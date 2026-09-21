extends Node
class_name ItemFactory

var rng := RandomNumberGenerator.new()

# empty at begining, fills by generated items.
var drop_pool: Array[Item] = []

const WEAPONS_DIR: String = "res://src/Resources/weapons"
var weapon_resources: Array[BaseWeapon] = []

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

func get_random_weapon() -> BaseWeapon:
    if weapon_resources.is_empty():
        _load_weapons()
    if weapon_resources.is_empty():
        return null
    return weapon_resources.pick_random()

func _load_weapons() -> void:
    var dir = DirAccess.open(WEAPONS_DIR)
    if not dir:
        push_warning("ItemFactory: could not open " + WEAPONS_DIR)
        return
    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
        if not dir.current_is_dir() and file_name.ends_with(".tres"):
            var res: Resource = load(WEAPONS_DIR + "/" + file_name)
            if res is BaseWeapon:
                weapon_resources.append(res)
        file_name = dir.get_next()
    dir.list_dir_end()

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
        "Enhances %s at a cost." % [chosen_stat],
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

    # Let the modifier randomize itself for generation (if it supports it),
    # then read back the actual configured values for naming.
    var configured_scene: PackedScene = _configure_dynamic_modifier(chosen_scene)
    var temp_instance = configured_scene.instantiate()
    var props := []
    for p in temp_instance.get_property_list():
        props.append(p.name)
    # Modifiers that randomize into variants (e.g. StatOnKill) expose a
    # suffix so generated items are distinguishable.
    if temp_instance.has_method("get_generation_suffix"):
        item_name += str(temp_instance.call("get_generation_suffix"))
        description = "Grants special effect: %s" % [item_name]
    if "trigger_event" in props:
        var trig = temp_instance.get("trigger_event")
        if trig != null:
            description += " (Triggers on %s)" % ItemTooltip.humanize_trigger(str(trig))
    temp_instance.free()

    #add negative effect
    var stat_names = stats.stats.keys()
    var negative_chosen_stat = stat_names[rng.randi_range(0, stat_names.size() - 1)]
    var negative_base_value = stats.stats[negative_chosen_stat]
    var negative_value: Dictionary = _generate_stat_modifiers(negative_chosen_stat, negative_base_value)
    negative_value.set("flat", -negative_value.get("flat") * 2)

    var item := ItemBuilder.make_effect_item(
        item_name,
        description,
        configured_scene,
        {negative_chosen_stat: negative_value}
    )
    _store_effect_display(item, configured_scene)
    return item

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

    # Modifiers may randomize themselves for generation (see
    # randomize_for_generation); the packed instance's actual trigger is
    # always read back at generation time.
    var configured_buff_scene: PackedScene = _configure_dynamic_modifier(chosen_scene)
    var buff_trigger := _read_scene_trigger(configured_buff_scene)
    var item_name = _generate_buff_name(chosen_scene.resource_path, chosen_stat)
    var description := "Grants a temporary buff: increases %s (Triggers on %s)." % [chosen_stat, ItemTooltip.humanize_trigger(buff_trigger)]

    var item := ItemBuilder.make_buff_item(item_name, description, chosen_stat, modifier_value, configured_buff_scene)
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

    # Same as buffs: always check the generated instance's actual trigger.
    var configured_debuff_scene: PackedScene = _configure_dynamic_modifier(chosen_scene)
    var debuff_trigger := _read_scene_trigger(configured_debuff_scene)
    var item_name = _generate_buff_name(chosen_scene.resource_path, chosen_stat)
    var description := "Grants a debuff: decreases %s (Triggers on %s)." % [chosen_stat, ItemTooltip.humanize_trigger(debuff_trigger)]

    var negative_chosen_stat = stat_names[rng.randi_range(0, stat_names.size() - 1)]
    var negative_base_value = stats.stats[negative_chosen_stat]
    var negative_value: Dictionary = _generate_stat_modifiers(negative_chosen_stat, negative_base_value)
    negative_value.set("flat", -negative_value.get("flat") * 2)

    var item := ItemBuilder.make_debuff_item(item_name, description, chosen_stat, modifier_value, configured_debuff_scene)
    item.modifiers[negative_chosen_stat] = negative_value
    return item

# -------------------
# Name Helpers
# -------------------
# Q8-C steady state: resolve modifier display text at build time so the
# tooltip never has to instantiate per hover. Stored as item metadata.
func _store_effect_display(item: Item, scene: PackedScene) -> void:
    if item == null or scene == null:
        return
    var instance: Node = scene.instantiate()
    if instance == null:
        return
    var props := {}
    for p in instance.get_property_list():
        props[p.name] = true
    var display_name := ""
    var tooltip_text := ""
    var tooltip_stats := ""
    var trigger := ""
    if props.has("display_name"):
        display_name = str(instance.get("display_name"))
    if props.has("tooltip_text"):
        tooltip_text = str(instance.get("tooltip_text"))
    if instance.has_method("get_tooltip_stats"):
        tooltip_stats = str(instance.call("get_tooltip_stats"))
    if props.has("trigger_event"):
        var trig = instance.get("trigger_event")
        if trig != null:
            trigger = str(trig)
    instance.free()
    if display_name.is_empty():
        display_name = ItemTooltip.humanize_effect_name(str(scene.resource_path.get_file().get_basename()))
    item.set_meta("effect_display_name", display_name)
    item.set_meta("effect_tooltip_text", tooltip_text)
    item.set_meta("effect_tooltip_stats", tooltip_stats)
    item.set_meta("effect_trigger", trigger)

# Read the actual trigger_event off a (possibly dynamically configured) scene.
func _read_scene_trigger(scene: PackedScene) -> String:
    if scene == null:
        return ""
    var instance: Node = scene.instantiate()
    if instance == null:
        return ""
    var trigger := ""
    for p in instance.get_property_list():
        if p.name == "trigger_event":
            var trig = instance.get("trigger_event")
            if trig != null:
                trigger = str(trig)
            break
    instance.free()
    return trigger

func _configure_dynamic_modifier(scene: PackedScene) -> PackedScene:
    # Delegation point: a modifier scene that supports generation-time
    # randomization implements `randomize_for_generation(context) -> bool`
    # and owns all of its own randomization (trigger tables, stat rolls,
    # amount scaling). The factory only builds the context, repacks when
    # the modifier reports a mutation, and otherwise returns the scene
    # untouched. Scenes without the hook (most modifiers, buffs) pass
    # through unchanged.
    var instance = scene.instantiate()
    if not instance.has_method("randomize_for_generation"):
        instance.free()
        return scene
    var context := {
        "rng": rng,
        "stats": stats.stats if stats != null else {},
    }
    var mutated: bool = bool(instance.call("randomize_for_generation", context))
    if not mutated:
        instance.free()
        return scene
    var repacked: PackedScene = ItemBuilder.pack_instance(instance)
    instance.free()
    return repacked

func _generate_stat_modifiers(_chosen_stat, base_value) -> Dictionary:
    var modifier_value = {}
    if base_value == 0:
        modifier_value["flat"] = 1
    elif base_value == 1:
        modifier_value["flat"] = float("%.2f" % [base_value * rng.randf_range(0.05, 0.1)])
    else:
        modifier_value["flat"] = float("%.2f" % [base_value * rng.randf_range(0.05, 0.1)])
    return modifier_value

func _generate_item_name(stat: String) -> String:
    return stat.capitalize() + " Plus"

func _generate_effect_name(path: String) -> String:
    var fname = path.get_file().get_basename()
    return fname.capitalize()

func _generate_buff_name(path: String, stat_name: String) -> String:
    var fname = path.get_file().get_basename()
    return fname.capitalize() + " " + stat_name
