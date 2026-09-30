extends Node
class_name ItemFactory

var rng := RandomNumberGenerator.new()

# empty at begining, fills by generated items.
var drop_pool: Array[Item] = []

const WEAPONS_DIR: String = "res://src/Resources/weapons"
var weapon_resources: Array[BaseWeapon] = []

## How often a generated item's curse is a real harmful **modifier** rather than
## a negated stat. Both are legitimate downsides; the modifier version is the one
## that actually costs you something every tick, so it stays well below half.
## Hardcoded rather than exported so the whole game shares one number; the pool
## it draws from is `_cost_effect_scenes()`, so widening it is a matter of
## tagging another modifier `effect_kind = COST`.
const NEGATIVE_MODIFIER_CHANCE: float = 0.35

@onready var stats: Stats = $Stats

# preload or lazy-load effect/buff scenes
var effect_scenes: Array[PackedScene] = []
var buff_scenes: Array[PackedScene] = []
var debuff_scene: PackedScene = null

func _ready():
    effect_scenes = ItemBuilder.load_scenes_from_dir("res://src/Systems/Items/modifiers")
    buff_scenes.append(load("res://src/Systems/Items/Buffs/buff.tscn"))
    debuff_scene = load("res://src/Systems/Items/Buffs/DebuffSource.tscn")


# -------------------
# Benefit / cost scene pools
# -------------------
## `effect_scenes` split by `BaseModifier.effect_kind`, computed once.
##
## Two jobs: the positive half of an item may only roll a BENEFIT, and the
## negative half may only roll a COST. Without the split the shop can offer
## "Grants special effect: Life Drain" as an upside, and the same scene can be
## picked for either half.
var _benefit_scenes: Array[PackedScene] = []
var _cost_scenes: Array[PackedScene] = []

func _rebuild_scene_pools() -> void:
    _benefit_scenes = []
    _cost_scenes = []
    for scene in effect_scenes:
        if _scene_effect_kind(scene) == BaseModifier.EffectKind.COST:
            _cost_scenes.append(scene)
        else:
            _benefit_scenes.append(scene)


func _benefit_effect_scenes() -> Array[PackedScene]:
    if _benefit_scenes.is_empty() and _cost_scenes.is_empty():
        _rebuild_scene_pools()
    return _benefit_scenes


func _cost_effect_scenes() -> Array[PackedScene]:
    if _benefit_scenes.is_empty() and _cost_scenes.is_empty():
        _rebuild_scene_pools()
    return _cost_scenes


## Read `effect_kind` off a temp instance. Probed by name because the folder also
## holds plain effect scenes that are not `BaseModifier`s at all; those count as
## BENEFIT.
func _scene_effect_kind(scene: PackedScene) -> int:
    if scene == null:
        return BaseModifier.EffectKind.BENEFIT
    var instance: Node = scene.instantiate()
    if instance == null:
        return BaseModifier.EffectKind.BENEFIT
    var kind := int(BaseModifier.EffectKind.BENEFIT)
    for p in instance.get_property_list():
        if p.name == "effect_kind":
            kind = int(instance.get("effect_kind"))
            break
    instance.free()
    return kind


## The curse for one generated item: either a harmful modifier appended as a
## second `effect_scene` entry, or - when the roll fails - a negated stat. The
## two are alternatives, never both, so an item never carries a double penalty.
func _roll_negative_modifier() -> bool:
    if _cost_effect_scenes().is_empty():
        return false
    return rng.randf() < NEGATIVE_MODIFIER_CHANCE


# -------------------
# Item Generation API
# -------------------

## Candidate stat names for generated stat/buff/debuff items: the static base
## stats plus every `provided_stat` advertised by the modifier scenes. A dynamic
## stat like `lifesteal` is therefore targetable even when no character owns its
## modifier yet (the flat modifier activates once the modifier is attached).
var _candidate_stats: Array = []

func _candidate_stat_names() -> Array:
    if _candidate_stats.is_empty():
        _candidate_stats = stats.stats.keys()
        for scene in effect_scenes:
            var instance: Node = scene.instantiate()
            if instance and "provided_stat" in instance:
                var stat_name: String = instance.get("provided_stat")
                if not stat_name.is_empty() and not stat_name in _candidate_stats:
                    _candidate_stats.append(stat_name)
            if instance:
                instance.free()
    return _candidate_stats

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
    var stat_names = _candidate_stat_names()
    var index_to_use = index if index != -1 else rng.randi_range(0, stat_names.size() - 1)
    var chosen_stat = stat_names[index_to_use]
    var base_value = stats.stats.get(chosen_stat, 0.0)
    var value = _generate_stat_modifiers(chosen_stat, base_value)

    var item_modifiers := {chosen_stat: value}
    var item := ItemBuilder.make_stat_item(
        _generate_item_name(chosen_stat),
        "Enhances %s at a cost." % [chosen_stat],
        item_modifiers
    )

    # A stat item has no positive effect scene, so a harmful one is its ONLY
    # entry. Its positive stat therefore lives in `modifiers` and the card has to
    # keep rendering that as a gain - `ItemTooltip._append_modifier_rows` decides
    # this from the fact that no scene is a BENEFIT.
    if _roll_negative_modifier():
        var cost_scene: PackedScene = _cost_effect_scenes().pick_random()
        item.effect_scene = [cost_scene]
        item.description = "Enhances %s, but bleeds you dry." % [chosen_stat]
    else:
        item.modifiers.merge(_roll_negative_stat(str(chosen_stat), stat_names, 1.0), true)
    return item

func _generate_effect_item(index: int = -1) -> Item:
    var benefit_scenes := _benefit_effect_scenes()
    var chosen_scene: PackedScene
    if index != -1:
        chosen_scene = effect_scenes[index]
    else:
        chosen_scene = benefit_scenes.pick_random()

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

    var item_scenes: Array[PackedScene] = [configured_scene]
    var extra_modifiers := {}
    if _roll_negative_modifier():
        # Appended AFTER the positive half so index 0 still reads as the gift and
        # `effect_scene_condition` stays aligned with a gift-first ordering.
        var cost_scene: PackedScene = _cost_effect_scenes().pick_random()
        item_scenes.append(_configure_dynamic_modifier(cost_scene))
    else:
        extra_modifiers = _roll_negative_stat("", _candidate_stat_names(), 2.0)

    var item := ItemBuilder.make_effect_item(
        item_name,
        description,
        item_scenes[0],
        extra_modifiers
    )
    item.effect_scene = item_scenes
    _store_effect_display(item, item_scenes)
    return item

func _generate_buff_item(index: int = -1) -> Item:
    var stat_names = _candidate_stat_names()

    var chosen_scene: PackedScene
    if index != -1:
        chosen_scene = buff_scenes[index]
    else:
        chosen_scene = buff_scenes.pick_random()

    var chosen_stat = stat_names[rng.randi_range(0, stat_names.size() - 1)]
    var base_value = stats.stats.get(chosen_stat, 0.0)
    var modifier_value = _generate_stat_modifiers(chosen_stat, base_value)

    # Modifiers may randomize themselves for generation (see
    # randomize_for_generation); the packed instance's actual trigger is
    # always read back at generation time.
    var configured_buff_scene: PackedScene = _configure_dynamic_modifier(chosen_scene)
    var buff_trigger := _read_scene_trigger(configured_buff_scene)
    var item_name = _generate_buff_name(chosen_scene.resource_path, chosen_stat)
    var description := "Grants a temporary buff: increases %s (Triggers on %s)." % [chosen_stat, ItemTooltip.humanize_trigger(buff_trigger)]

    var item := ItemBuilder.make_buff_item(item_name, description, chosen_stat, modifier_value, configured_buff_scene)
    _attach_roll_negative_half(item, str(chosen_stat), stat_names, 1.0)
    return item

func _generate_debuff_item(_index: int = -1) -> Item:
    var stat_names = _candidate_stat_names()
    var chosen_scene: PackedScene = debuff_scene

    var chosen_stat = stat_names[rng.randi_range(0, stat_names.size() - 1)]
    var base_value = stats.stats.get(chosen_stat, 0.0)
    var modifier_value: Dictionary = _generate_stat_modifiers(chosen_stat, base_value)
    var value: float = modifier_value.get("flat")
    modifier_value.set("flat", -value)

    # Same as buffs: always check the generated instance's actual trigger.
    var configured_debuff_scene: PackedScene = _configure_dynamic_modifier(chosen_scene)
    var debuff_trigger := _read_scene_trigger(configured_debuff_scene)
    var item_name = _generate_buff_name(chosen_scene.resource_path, chosen_stat)
    var description := "Grants a debuff: decreases %s (Triggers on %s)." % [chosen_stat, ItemTooltip.humanize_trigger(debuff_trigger)]

    var item := ItemBuilder.make_debuff_item(item_name, description, chosen_stat, modifier_value, configured_debuff_scene)
    _attach_roll_negative_half(item, str(chosen_stat), stat_names, 2.0)
    return item


## The item's curse, for the generators that already have a positive effect scene
## at index 0. Either a harmful modifier appended after it, or a negated stat.
func _attach_roll_negative_half(item: Item, exclude: String, stat_names: Array, scale: float) -> void:
    if _roll_negative_modifier():
        var item_scenes: Array[PackedScene] = []
        for scene in item.effect_scene:
            item_scenes.append(scene)
        var cost_scene: PackedScene = _cost_effect_scenes().pick_random()
        item_scenes.append(_configure_dynamic_modifier(cost_scene))
        item.effect_scene = item_scenes
        _store_effect_display(item, item_scenes)
    else:
        _apply_negative_half(item, exclude, stat_names, scale)


## One negated stat entry, scaled so an item's downside outweighs its upside
## (`scale` 2.0 where the positive half is a flat effect).
##
## `exclude` is the stat the positive half already uses. Picking it again would
## collapse both halves onto one key, and since `Dictionary.merge()` does not
## overwrite by default the curse would vanish entirely - leaving a free item.
func _roll_negative_stat(exclude: String, stat_names: Array, scale: float) -> Dictionary:
    var candidates := []
    for stat_name in stat_names:
        if stat_name != exclude:
            candidates.append(stat_name)
    if candidates.is_empty():
        return {}
    var negative_chosen_stat = candidates[rng.randi_range(0, candidates.size() - 1)]
    var negative_base_value = stats.stats.get(negative_chosen_stat, 0.0)
    var negative_value: Dictionary = _generate_stat_modifiers(negative_chosen_stat, negative_base_value)
    negative_value.set("flat", -negative_value.get("flat") * scale)
    return {negative_chosen_stat: negative_value}


## Apply a curse dict onto an item that has no stat modifiers of its own.
func _apply_negative_half(item: Item, exclude: String, stat_names: Array, scale: float) -> void:
    var negative := _roll_negative_stat(exclude, stat_names, scale)
    for stat_name in negative:
        item.modifiers[stat_name] = negative[stat_name]

# -------------------
# Name Helpers
# -------------------
# Q8-C steady state: resolve modifier display text at build time so the
# tooltip never has to instantiate per hover. Stored as item metadata.
#
# One entry per effect scene, aligned by index with `item.effect_scene` (the
# convention `Item.effect_scene_condition` already uses), because an item can
# carry a positive AND a harmful modifier and each needs its own name, stats,
# trigger and BENEFIT/ COST marker.
func _store_effect_display(item: Item, scenes: Array[PackedScene]) -> void:
    if item == null or scenes == null:
        return
    var displays := []
    for scene in scenes:
        displays.append(_read_effect_display(scene))
    item.set_meta("effect_displays", displays)


func _read_effect_display(scene: PackedScene) -> Dictionary:
    var display := {
        "name": "",
        "text": "",
        "stats": "",
        "trigger": "",
        "effect_kind": int(BaseModifier.EffectKind.BENEFIT),
    }
    if scene == null:
        return display
    var instance: Node = scene.instantiate()
    if instance == null:
        return display
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
    # BENEFIT / COST marker. Cached like the rest of the display so a generated
    # life-drain item still renders its effect line red after the temp instance
    # is gone. Probed by name because not every effect scene is a BaseModifier.
    var effect_kind := int(BaseModifier.EffectKind.BENEFIT)
    if props.has("effect_kind"):
        effect_kind = int(instance.get("effect_kind"))
    instance.free()
    if display_name.is_empty():
        display_name = ItemTooltip.humanize_effect_name(str(scene.resource_path.get_file().get_basename()))
    display["name"] = display_name
    display["text"] = tooltip_text
    display["stats"] = tooltip_stats
    display["trigger"] = trigger
    display["effect_kind"] = effect_kind
    return display

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
