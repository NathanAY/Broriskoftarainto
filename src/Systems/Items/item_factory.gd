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
## The pool it draws from is `_cost_effect_scenes()`, so widening it is a matter
## of tagging another modifier `effect_kind = COST`.
##
## This and the two knobs below are read from `res://game_config.json`
## (`item_generation` block); the literals here are only the fallback for a
## missing key. See `docs/systems/game_config.md`.
var negative_modifier_chance: float = float(GameConfig.section("item_generation").get("negative_modifier_chance", 0.35))

## Scales how often `get_item_from_pool_or_generate()` re-offers an item it has
## already generated. 1.0 is the raw `N / (N + 1)` pool hit rate, 0.25 a quarter
## of it, 0.0 a brand new item every time.
var repeat_item_chance_scale: float = float(GameConfig.section("item_generation").get("repeat_item_chance_scale", 0.25))

## Drop weight per modifier scene, keyed by the scene's file name without
## `.tscn`. A scene that is not listed weighs 1.0.
var modifier_weights: Dictionary = GameConfig.section("item_generation").get("modifier_weights", {})

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
    return rng.randf() < negative_modifier_chance


## One scene from `scenes`, drawn by `modifier_weights`. Weights are relative
## within the list handed in, so lowering one cost only shifts the roll towards
## the other costs - how often a cost appears at all is
## `negative_modifier_chance`. If every weight is zero the pick is uniform.
func _pick_weighted_scene(scenes: Array[PackedScene]) -> PackedScene:
    var weights: Array[float] = []
    var total := 0.0
    for scene in scenes:
        var weight := maxf(0.0, float(modifier_weights.get(scene.resource_path.get_file().get_basename(), 1.0)))
        weights.append(weight)
        total += weight
    if total <= 0.0:
        return scenes[rng.randi_range(0, scenes.size() - 1)]
    var roll := rng.randf() * total
    for i in range(scenes.size()):
        roll -= weights[i]
        if roll < 0.0:
            return scenes[i]
    return scenes[scenes.size() - 1]


# -------------------
# Item Generation API
# -------------------

## Candidate stat names for generated stat/buff/debuff items: the static base
## stats plus every `provided_stat` advertised by the modifier scenes. A dynamic
## stat like `life_leach_multiplier` is therefore targetable even when no character owns its
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

## Stat names that never roll as plain stat values: the two regen rates only fire
## through a regen modifier, so a bare `{"flat_regen_per_second": ...}` would be a
## number nothing reads. They reach the player as the modifier item, which
## publishes its value into the stat (see `regen_modifier.gd`).
const LISTENER_ONLY_STATS: Array[String] = [
	"flat_regen_per_second",
	"percent_regen_per_second",
]

## The candidates a stat value may be rolled from: the full candidate list minus
## the listener-only stats.
func _gratable_stat_names() -> Array:
    var names: Array = []
    for stat_name in _candidate_stat_names():
        if not stat_name in LISTENER_ONLY_STATS:
            names.append(stat_name)
    return names

## Stats a buff or debuff may carry: the economy stats are only read at the
## shop or on a kill, so a few seconds of "+2 stock" would do nothing.
func _temporary_stat_names() -> Array:
    return _gratable_stat_names().filter(func(stat_name): return not stat_name in Wallet.ECONOMY_STATS)

func get_item_from_pool_or_generate() -> Item:
    var pool_size := drop_pool.size()
    # An empty pool gives a chance of 0, so the first call always generates.
    if rng.randf() < repeat_item_chance_scale * pool_size / (pool_size + 1.0):
        return drop_pool.pick_random()
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
    var item: Item
    if roll < 0.4:
        item = _generate_stat_item()
    elif roll < 0.7:
        item = _generate_effect_item()
    elif roll < 0.85:
        item = _generate_buff_item()
    else:
        item = _generate_debuff_item()
    apply_rarity(item, roll_rarity(_current_stage()))
    return item

# -------------------
# Rarity
# -------------------
## How much each stage past the first boosts the higher tiers' weights: tier `i`
## weighs `weight * (1 + growth * (stage - 1) * i)`. Read from `game_config.json`.
var rarity_stage_growth: float = float(GameConfig.section("item_rarity").get("stage_weight_growth", 0.5))

func roll_rarity(stage: int) -> BaseWeapon.Rarity:
    var weights: Array[float] = []
    var total := 0.0
    for i in range(BaseWeapon.Rarity.LEGENDARY + 1):
        var weight := maxf(0.0, Item.rarity_value("weights", i) * (1.0 + rarity_stage_growth * maxi(0, stage - 1) * i))
        weights.append(weight)
        total += weight
    var pick := rng.randf() * total
    for i in range(weights.size()):
        pick -= weights[i]
        if pick < 0.0:
            return i as BaseWeapon.Rarity
    return BaseWeapon.Rarity.COMMON


## Stamps `rarity` on a freshly generated item: gains scale by the rarity's
## positive multiplier, losses by its (smaller) negative one, then up to
## `rarity` extra gain lines and one extra loss line are rolled on stats the
## item does not touch yet.
func apply_rarity(item: Item, rarity: BaseWeapon.Rarity) -> void:
    if item == null:
        return
    item.rarity = rarity
    var gain := Item.rarity_value("positive_multipliers", rarity)
    var loss := Item.rarity_value("negative_multipliers", rarity)
    _scale_flats(item.modifiers, gain, loss)
    # A buff/debuff payload is the item's gain even when it is negative (a
    # debuff lowers the enemy's stat), so all of it scales by `gain`.
    if ItemTooltip.is_buff_item(item) or ItemTooltip.is_debuff_item(item):
        var payload: Node = item.effect_scene[0].instantiate()
        _scale_flats(payload.modifiers, gain, gain)
        item.effect_scene[0] = ItemBuilder.pack_instance(payload)
        payload.free()
    for i in range(int(rarity)):
        if rng.randf() < Item.rarity_value("extra_positive_chance", rarity):
            _add_stat_line(item, gain)
    if rng.randf() < Item.rarity_value("extra_negative_chance", rarity):
        _add_stat_line(item, -loss)


func _scale_flats(modifiers: Dictionary, gain: float, loss: float) -> void:
    for stat_name in modifiers:
        var entry = modifiers[stat_name]
        if entry is Dictionary and entry.has("flat"):
            var flat := float(entry["flat"])
            entry["flat"] = snappedf(flat * (gain if flat > 0.0 else loss), 0.01)


## One more stat line on a stat the item does not modify yet, rolled like any
## other stat value and multiplied by `scale` (negative for a loss).
func _add_stat_line(item: Item, scale: float) -> void:
    var candidates := []
    for stat_name in _gratable_stat_names():
        if not item.modifiers.has(stat_name):
            candidates.append(stat_name)
    if candidates.is_empty():
        return
    var chosen := _pick_stat_name(candidates)
    var value := _generate_stat_modifiers(chosen, stats.stats.get(chosen, 0.0))
    value["flat"] = snappedf(float(value["flat"]) * scale, 0.01)
    item.modifiers[chosen] = value


func _current_stage() -> int:
    return StageManager.stage_of(self)

func _generate_stat_item(index: int = -1) -> Item:
    var stat_names = _gratable_stat_names()
    var chosen_stat = stat_names[index] if index != -1 else _pick_stat_name(stat_names)
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
        var cost_scene: PackedScene = _pick_weighted_scene(_cost_effect_scenes())
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
        chosen_scene = _pick_weighted_scene(benefit_scenes)

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
        var cost_scene: PackedScene = _pick_weighted_scene(_cost_effect_scenes())
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
    var stat_names = _temporary_stat_names()

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
    var description := "Buff: increases %s (Triggers on %s)." % [chosen_stat, ItemTooltip.humanize_trigger(buff_trigger)]

    var item := ItemBuilder.make_buff_item(item_name, description, chosen_stat, modifier_value, configured_buff_scene)
    _attach_roll_negative_half(item, str(chosen_stat), stat_names, 1.0)
    return item

func _generate_debuff_item(_index: int = -1) -> Item:
    var stat_names = _temporary_stat_names()
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
    var description := "Debuff: decreases %s (Triggers on %s)." % [chosen_stat, ItemTooltip.humanize_trigger(debuff_trigger)]

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
        var cost_scene: PackedScene = _pick_weighted_scene(_cost_effect_scenes())
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
        # A curse on a listener-only stat is as dead as the positive half would
        # be: on a character without the modifier, a negated regen rate changes nothing.
        if stat_name != exclude and not stat_name in LISTENER_ONLY_STATS:
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
    var item_damage_fraction := 0.0
    if instance.has_method("tooltip_item_damage_fraction"):
        item_damage_fraction = float(instance.call("tooltip_item_damage_fraction"))
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
    display["item_damage_fraction"] = item_damage_fraction
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

## Per-stat overrides from `game_config.json` (`item_generation.stat_overrides`),
## keyed by stat name. Each entry may set `min_roll` and/or `pick_weight`; a stat
## or key that is not listed gets no override.
var stat_overrides: Dictionary = GameConfig.section("item_generation").get("stat_overrides", {})

## A random entry of `names`, weighted by each stat's `pick_weight` override
## (1 when it has none).
func _pick_stat_name(names: Array) -> String:
    var total := 0.0
    for stat_name in names:
        total += _pick_weight(str(stat_name))
    var roll := rng.randf() * total
    for stat_name in names:
        roll -= _pick_weight(str(stat_name))
        if roll < 0.0:
            return str(stat_name)
    return str(names[names.size() - 1])

func _pick_weight(stat_name: String) -> float:
    return maxf(0.0, float(stat_overrides.get(stat_name, {}).get("pick_weight", 1.0)))

func _generate_stat_modifiers(chosen_stat, base_value) -> Dictionary:
    var modifier_value = {}
    if base_value == 0:
        modifier_value["flat"] = float(stat_overrides.get(str(chosen_stat), {}).get("roll", 1.0))
    else:
        modifier_value["flat"] = float("%.2f" % [base_value * rng.randf_range(0.05, 0.1)])
    var min_roll = stat_overrides.get(str(chosen_stat), {}).get("min_roll")
    if min_roll != null:
        modifier_value["flat"] = maxf(float(modifier_value["flat"]), float(min_roll))
    return modifier_value

func _generate_item_name(stat: String) -> String:
    return stat.capitalize() + " Plus"

func _generate_effect_name(path: String) -> String:
    var fname = path.get_file().get_basename()
    return fname.capitalize()

func _generate_buff_name(path: String, stat_name: String) -> String:
    var fname = path.get_file().get_basename()
    return fname.capitalize() + " " + stat_name
