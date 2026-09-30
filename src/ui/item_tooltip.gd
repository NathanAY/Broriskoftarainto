extends RefCounted
class_name ItemTooltip

## Static builder of tooltip key-value lines for Item, BaseWeapon and
## CharacterData resources. CharacterData delegates to CharacterTooltip.
## Clarity rules (docs/plans/item-tooltip-clarity.md):
## - Weapons: name/damage/range/attack speed, plus one line per built-in effect
##   declared in BaseWeapon.modifiers (pierce/knockback/poison).
## - Stat items: name + modifier lines only, ignore description.
## - Effect items: name + single `effect:` line (modifier-owned text) + `tradeoff:` lines.
## - Buff/debuff: name + clean flavor? + `buff:`/`debuff:` payload + `tradeoff:` lines.

static var _effect_display_cache: Dictionary = {}

## Plain-text hints explaining what each stat does, shown in the Stats list tooltips.
## Multi-line strings render as separate lines inside the tooltip card.
const STAT_HINTS: Dictionary = {
    "health": "Maximum hit points. You die when it reaches 0.",
    "energy_shield": "Shield that absorbs incoming damage before health. Recharges over time.",
    "damage": "Overall damage multiplier applied to all attacks.\nFormula: (base_damage + flat_damage) * damage.",
    "base_damage": "Base damage of your weapon before any multipliers.",
    "flat_damage": "Flat damage added to every hit.\nGreat for fast-attacking weapons with low base damage, since it scales with hits per second.",
    "attack_speed": "Attack speed multiplier. Higher = more attacks per second = more on-hit effects.",
    "area_radius": "Radius of area attacks and melee swings.",
    "attack_range": "Maximum distance at which your weapons can hit targets.",
    "movement_speed": "Movement speed in meters per second (m/s).",
    "armor": "Reduces incoming damage.\nFormula: final damage x (10 / (10 + armor)).\nExample: 1 armor blocks about 9%% (multiplier 0.91).\nExample: 10 armor blocks 50%% (multiplier 0.50).",
    "critical_chance": "Chance per hit to land a critical strike (in percent, 0-100).",
    "critical_multiplier": "Critical strikes multiply your damage by this value (1.5 = 150%%).",
    "area_size_multiplier": "Multiplier for the size of explosions and area effects.",
    "projectile_pierce": "Number of enemies a projectile can pass through before disappearing.",
    "projectile_speed_multiplier": "Multiplier for projectile travel speed.",
    "lifeleach": "Heals for amount of dealt damage.",
    "money": "Currency used to buy and reroll items in the shop.",
}


static func stat_hint(stat_name: String) -> String:
    return str(STAT_HINTS.get(stat_name, ""))


static func tooltip_lines(resource: Resource) -> PackedStringArray:
    var lines := PackedStringArray()
    if resource is CharacterData:
        return CharacterTooltip.tooltip_lines(resource)
    if resource is BaseWeapon:
        lines.append("name: " + str(resource.name))
        lines.append("damage: " + str(resource.base_damage))
        lines.append("range: " + str(resource.weapon_range))
        lines.append("attack speed: " + str(resource.base_attack_speed))
        for line in WeaponBuiltinEffects.builtin_tooltip_lines(resource):
            lines.append(line)
        return lines
    elif resource is Item:
        var item: Item = resource
        if is_buff_item(item):
            _append_buff_debuff_lines(lines, item, "buff")
            return lines
        if is_debuff_item(item):
            _append_buff_debuff_lines(lines, item, "debuff")
            return lines
        if has_effect_scene(item):
            lines.append("name: " + str(item.name))
            _append_effect_line(lines, item)
            _append_tradeoff_lines(lines, item.modifiers)
            return lines
        # Stat item: name + modifier lines, skip description.
        lines.append("name: " + str(item.name))
        for line in modifier_lines(item.modifiers):
            lines.append(line)
        return lines
    return lines


## Structured counterpart of `tooltip_lines()`, used by `ShopItemCard` so
## each line can be colored and get its own stat icon. `tooltip_lines()`
## stays the flat-text source for hover tooltips and is left untouched.
static func card_rows(resource: Resource) -> Array:
    var rows: Array = []
    if resource is CharacterData:
        return CharacterTooltip.card_rows(resource as CharacterData)
    if resource is BaseWeapon:
        return weapon_card_rows(resource as BaseWeapon)
    if not (resource is Item):
        return rows

    var item: Item = resource
    if is_buff_item(item) or is_debuff_item(item):
        _append_buff_debuff_rows(rows, item)
    else:
        _append_name_row(rows, item.name)
        _append_effect_rows(rows, item)
        _append_modifier_rows(rows, item)
    return rows


static func weapon_card_rows(weapon: BaseWeapon) -> Array:
    var rows: Array = []
    if weapon == null:
        return rows
    _append_name_row(rows, weapon.name)
    _append_weapon_row(rows, "Damage", str(weapon.base_damage))
    _append_weapon_row(rows, "Range", str(weapon.weapon_range))
    _append_weapon_row(rows, "Attack Speed", str(weapon.base_attack_speed))
    for line in WeaponBuiltinEffects.builtin_tooltip_lines(weapon):
        var split := _split_key_value(line)
        _append_weapon_row(rows, humanize_effect_name(split[0]), split[1])
    return rows


static func _append_name_row(rows: Array, display_name: String) -> void:
    var row := ItemCardRow.new()
    row.kind = ItemCardRow.Kind.NAME
    row.label = humanize_effect_name(str(display_name))
    rows.append(row)


static func _append_weapon_row(rows: Array, label: String, value: String) -> void:
    var row := ItemCardRow.new()
    row.kind = ItemCardRow.Kind.WEAPON
    row.tone = _tone_for_value(value)
    row.label = label
    row.value = _signed(value)
    rows.append(row)


## Turns a `{stat: {kind: value}}` modifier dictionary into rows. Shared with
## CharacterTooltip so a character's stat modifiers render exactly like a shop
## item's. `force_tone` overrides the value-derived tone (used for tradeoffs).
static func stat_rows(modifiers: Dictionary, force_tone: int = -1) -> Array:
    var rows: Array = []
    _append_stat_rows(rows, modifiers, force_tone)
    return rows


static func _append_stat_rows(rows: Array, modifiers: Dictionary, force_tone: int = -1) -> void:
    for stat_name in modifiers:
        var mod = modifiers[stat_name]
        if typeof(mod) != TYPE_DICTIONARY:
            continue
        for mod_type in mod:
            var value = mod[mod_type]
            var row := ItemCardRow.new()
            row.kind = ItemCardRow.Kind.STAT
            row.stat_name = str(stat_name)
            row.icon = Stats.get_stat_icon(str(stat_name))
            # "percent" already shows up in the rendered value as a % sign, and
            # "flat" is the default flavour, so only unusual kinds are named.
            row.label = humanize_effect_name(str(stat_name))
            if mod_type != "flat":
                row.label += " %s" % str(mod_type)
            if mod_type == "percent":
                var shown := "%d%%" % round(float(value) * 100.0)
                row.value = _signed(shown)
                row.tone = force_tone if force_tone >= 0 else _tone_for_number(float(value))
            else:
                row.value = _signed(str(value))
                row.tone = force_tone if force_tone >= 0 else _tone_for_number(_as_number(value))
            rows.append(row)


## Renders a raw stat value without a sign. Used for absolute values (a
## character's `base_stats`) where the colour, not the prefix, says whether
## the number is high or low. Whole floats drop the ".0" noise.
static func format_value(value) -> String:
    var trimmed := str(value).strip_edges()
    if trimmed.is_valid_float():
        var number := trimmed.to_float()
        if number == floorf(number):
            return str(int(number))
    return trimmed


## One EFFECT row per entry of `item.effect_scene` from `start_index` on, in
## order, each toned by its own `BaseModifier.effect_kind`. An item that carries
## both a helpful and a harmful modifier therefore shows both lines - showing only
## the first would hide the downside from the player while the holder still
## applied it.
static func _append_effect_rows(rows: Array, item: Item, start_index: int = 0) -> void:
    if not has_effect_scene(item):
        return
    for i in range(maxi(0, start_index), item.effect_scene.size()):
        _append_effect_row(rows, item, i)


static func _append_effect_row(rows: Array, item: Item, index: int) -> void:
    var display: Dictionary = resolve_effect_display_for_item(item, index)
    var effect_name := humanize_effect_name(str(display.get("name", "")))
    if effect_name.is_empty():
        return
    var body_parts := PackedStringArray()
    var text := str(display.get("text", ""))
    if not text.is_empty():
        body_parts.append(text)
    var stats := str(display.get("stats", ""))
    if not stats.is_empty():
        body_parts.append(stats)
    var row := ItemCardRow.new()
    row.kind = ItemCardRow.Kind.EFFECT
    row.tone = _tone_for_effect_kind(int(display.get("effect_kind", BaseModifier.EffectKind.BENEFIT)))
    row.text = " — ".join([effect_name] + Array(body_parts))
    var trigger := str(display.get("trigger", ""))
    if not trigger.is_empty():
        row.text += " (on %s)" % humanize_trigger(trigger)
    rows.append(row)


## An item's positive half lives either in its effect scenes (an "effect item")
## or in its stat modifiers (a plain stat item). When any scene is a BENEFIT the
## item is an effect item and every stat modifier on it is a cost, so they are
## forced red; otherwise the item is a stat item that merely carries a drawback,
## and each modifier keeps the tone its own value implies - otherwise the
## positive stat would be rendered as a tradeoff.
static func _append_modifier_rows(rows: Array, item: Item) -> void:
    var force_tone := -1
    if _has_benefit_effect(item):
        force_tone = ItemCardRow.Tone.NEGATIVE
    _append_stat_rows(rows, item.modifiers, force_tone)


static func _has_benefit_effect(item: Item) -> bool:
    if not has_effect_scene(item):
        return false
    for i in item.effect_scene.size():
        var kind := int(resolve_effect_display_for_item(item, i).get(
            "effect_kind", BaseModifier.EffectKind.BENEFIT))
        if kind != BaseModifier.EffectKind.COST:
            return true
    return false


## A modifier that declares itself a COST (life drain, ...) gets a red effect
## line; everything else stays neutral, which the card renders as heading gold.
## Mapped by name rather than cast: `EffectKind` and `Tone` are separate enums
## and are free to number their entries differently.
static func _tone_for_effect_kind(effect_kind: int) -> int:
    match effect_kind:
        BaseModifier.EffectKind.COST:
            return ItemCardRow.Tone.NEGATIVE
        _:
            return ItemCardRow.Tone.NEUTRAL


static func _append_tradeoff_rows(rows: Array, modifiers: Dictionary) -> void:
    _append_stat_rows(rows, modifiers, ItemCardRow.Tone.NEGATIVE)


## A buff or debuff payload row is a gain **for the player** in both cases: a
## buff lifts the holder, a debuff drags the enemy down, and the card is priced
## and read from the player's side. The sign on the number still says which way
## the stat moved - a debuff shows `-0.12 Critical Multiplier` - but painting it
## red made the card read as a penalty the player was paying for, which is the
## opposite of what the item does. The item's *own* curse is a real loss and
## keeps its red through `_append_tradeoff_rows` / `_append_effect_rows`.
static func _append_buff_debuff_rows(rows: Array, item: Item) -> void:
    _append_name_row(rows, item.name)
    var flavor := str(item.description)
    if not flavor.is_empty() and is_clean_flavor(flavor):
        var row := ItemCardRow.new()
        row.kind = ItemCardRow.Kind.FLAVOR
        row.text = _leads_into_next_row(_flavor_with_trigger(flavor, item))
        rows.append(row)
    var payload := peek_packed_modifiers(item.effect_scene[0] if has_effect_scene(item) else null)
    _append_stat_rows(rows, payload, ItemCardRow.Tone.POSITIVE)
    # Index 0 is the buff/debuff payload itself and is already rendered as the
    # toned stat rows above. Any scene after it is a harmful modifier the factory
    # added as this item's curse, so it has to be shown or the item reads as a
    # free upgrade.
    _append_effect_rows(rows, item, 1)
    _append_tradeoff_rows(rows, item.modifiers)


## The grey sentence introduces the stat line under it, so a trailing full stop
## would close the sentence before the number that completes it. Swapping it for
## a colon ties the two into one readable block.
static func _leads_into_next_row(flavor: String) -> String:
    var trimmed := flavor.strip_edges()
    if trimmed.is_empty():
        return flavor
    if trimmed.ends_with("."):
        return trimmed.substr(0, trimmed.length() - 1) + ":"
    if trimmed.ends_with(":"):
        return trimmed
    return trimmed + ":"


## Splits "pierce: 1" into ["pierce", "1"]. Falls back to ["text", ""].
static func _split_key_value(line: String) -> Array:
    var idx := line.find(":")
    if idx < 0:
        return [line, ""]
    return [line.substr(0, idx).strip_edges(), line.substr(idx + 1).strip_edges()]


## Adds an explicit "+" to non-negative numbers so gains and losses read
## the same way as the stat icons beside them.
static func _signed(value: String) -> String:
    var trimmed := value.strip_edges()
    if trimmed.is_empty() or trimmed.begins_with("+") or trimmed.begins_with("-"):
        return trimmed
    # Whole floats render as "5.0" in GDScript; the trailing ".0" is noise on
    # a stat line, so drop it. Values that are not whole keep full precision.
    if trimmed.is_valid_float():
        var number := trimmed.to_float()
        if number == floorf(number):
            trimmed = str(int(number))
    return "+" + trimmed


## Modifier payloads can hold ints, floats or pre-formatted strings.
## Returns NAN for anything non-numeric so it falls back to NEUTRAL.
static func _as_number(value) -> float:
    if value is int or value is float:
        return float(value)
    return String(str(value)).to_float()


## Tone comes from the numeric value, not the rendered string: a positive
## float renders as "5.0" which never carries an explicit "+".
static func _tone_for_number(number: float) -> int:
    if number < 0.0:
        return ItemCardRow.Tone.NEGATIVE
    if number > 0.0:
        return ItemCardRow.Tone.POSITIVE
    return ItemCardRow.Tone.NEUTRAL


static func _tone_for_value(value: String) -> int:
    var trimmed := value.strip_edges()
    if trimmed.begins_with("-"):
        return ItemCardRow.Tone.NEGATIVE
    if trimmed.begins_with("+"):
        return ItemCardRow.Tone.POSITIVE
    return ItemCardRow.Tone.NEUTRAL


static func modifier_lines(modifiers: Dictionary) -> PackedStringArray:
    var lines := PackedStringArray()
    for stat_name in modifiers:
        var mod = modifiers[stat_name]
        if typeof(mod) != TYPE_DICTIONARY:
            continue
        for mod_type in mod:
            var value = mod[mod_type]
            if mod_type == "percent":
                lines.append("%s %s: %d%%" % [stat_name, mod_type, round(float(value) * 100.0)])
            else:
                lines.append("%s %s: %s" % [stat_name, mod_type, str(value)])
    return lines


static func is_buff_item(item: Item) -> bool:
    return item.has_meta("type") and str(item.get_meta("type")) == "buff"


static func is_debuff_item(item: Item) -> bool:
    return item.has_meta("type") and str(item.get_meta("type")) == "debuff"


static func has_effect_scene(item: Item) -> bool:
    return item.effect_scene != null and item.effect_scene.size() > 0


static func _append_tradeoff_lines(lines: PackedStringArray, modifiers: Dictionary) -> void:
    for line in modifier_lines(modifiers):
        lines.append("tradeoff: " + line)


static func _append_effect_line(lines: PackedStringArray, item: Item) -> void:
    # Every scene, not just the first: an item with a positive and a harmful
    # modifier must name both here too, or the hover tooltip would disagree with
    # the card.
    if not has_effect_scene(item):
        return
    for i in item.effect_scene.size():
        var line := _effect_line_text(item, i)
        if not line.is_empty():
            lines.append("effect: " + line)


static func _effect_line_text(item: Item, index: int) -> String:
    var display: Dictionary = resolve_effect_display_for_item(item, index)
    var effect_name := str(display.get("name", ""))
    if effect_name.is_empty():
        return ""
    var head := effect_name
    var body_parts := PackedStringArray()
    var text := str(display.get("text", ""))
    if not text.is_empty():
        body_parts.append(text)
    var stats := str(display.get("stats", ""))
    if not stats.is_empty():
        body_parts.append(stats)
    if body_parts.size() > 0:
        head += " — " + " ".join(body_parts)
    var trigger := str(display.get("trigger", ""))
    if not trigger.is_empty():
        head += " (Triggers on %s)" % humanize_trigger(trigger)
    return head


static func _append_buff_debuff_lines(lines: PackedStringArray, item: Item, prefix: String) -> void:
    lines.append("name: " + str(item.name))
    var flavor := str(item.description)
    if not flavor.is_empty() and is_clean_flavor(flavor):
        lines.append(_flavor_with_trigger(flavor, item))
    var payload := peek_packed_modifiers(item.effect_scene[0] if has_effect_scene(item) else null)
    for line in modifier_lines(payload):
        lines.append(prefix + ": " + line)
    # Scene 0 is the payload (rendered above); anything after it is a harmful
    # modifier that is this item's curse, so it needs a line of its own.
    if has_effect_scene(item):
        for i in range(1, item.effect_scene.size()):
            var line := _effect_line_text(item, i)
            if not line.is_empty():
                lines.append("effect: " + line)
    _append_tradeoff_lines(lines, item.modifiers)


static func is_clean_flavor(description: String) -> bool:
    # Transitional guard: old factory descriptions embedded raw dicts ("{...}").
    # Clean flavor (flavor + trigger only) never contains braces.
    return not ("{" in description or "}" in description)


## Steady state (Q8-C): prefer build-time resolved values stored on the item;
## fallback (Q8-A): temp instantiate, read contract fields, free, cache per path.
##
## `item` may carry several effect scenes (a positive plus a harmful one), so the
## cache is an Array **aligned by index with `item.effect_scene`** - the same
## convention as `Item.effect_scene_condition`. Keying by scene path would not
## work: `_configure_dynamic_modifier` repacks randomized modifiers into a
## `PackedScene` with an empty `resource_path`.
static func resolve_effect_displays_for_item(item: Item) -> Array:
    if item != null and item.has_meta("effect_displays"):
        var cached = item.get_meta("effect_displays")
        if typeof(cached) == TYPE_ARRAY:
            return cached
    return []


## Cached display for `effect_scene[index]`, falling back to reflecting on the
## scene when the item was never passed through `ItemFactory`.
static func resolve_effect_display_for_item(item: Item, index: int) -> Dictionary:
    var cached := resolve_effect_displays_for_item(item)
    if index >= 0 and index < cached.size():
        return cached[index]
    if item != null and item.effect_scene != null and index >= 0 and index < item.effect_scene.size():
        return resolve_effect_display(item.effect_scene[index])
    return _empty_effect_display()


static func resolve_effect_display(scene: PackedScene) -> Dictionary:
    var empty := _empty_effect_display()
    if scene == null:
        return empty.duplicate()
    var path := str(scene.resource_path)
    if not path.is_empty() and _effect_display_cache.has(path):
        return (_effect_display_cache[path] as Dictionary).duplicate()
    var display := _read_display_from_scene(scene)
    if not path.is_empty() and not str(display.get("name", "")).is_empty():
        _effect_display_cache[path] = display.duplicate()
    return display


static func _empty_effect_display() -> Dictionary:
    return {
        "name": "",
        "text": "",
        "stats": "",
        "trigger": "",
        "effect_kind": BaseModifier.EffectKind.BENEFIT,
    }


static func _read_display_from_scene(scene: PackedScene) -> Dictionary:
    var display := _empty_effect_display()
    var instance: Node = scene.instantiate()
    if instance == null:
        return display
    var props := {}
    for p in instance.get_property_list():
        props[p.name] = true
    if props.has("display_name"):
        display["name"] = str(instance.get("display_name"))
    if props.has("tooltip_text"):
        display["text"] = str(instance.get("tooltip_text"))
    # Optional dynamic fragment with the configured numbers (heal amount,
    # damage %, regen values). Lives on the modifier so it always reads
    # live values, never stale static text.
    if instance.has_method("get_tooltip_stats"):
        display["stats"] = str(instance.call("get_tooltip_stats"))
    if props.has("trigger_event"):
        var trig = instance.get("trigger_event")
        if trig != null:
            display["trigger"] = str(trig)
    # BENEFIT / COST marker read from the BaseModifier export. Present on every
    # modifier via the base class, but still probed defensively because this
    # also sees plain effect scenes (explosions, projectile spawners) that are
    # not BaseModifiers at all.
    if props.has("effect_kind"):
        display["effect_kind"] = int(instance.get("effect_kind"))
    if str(display["name"]).is_empty():
        display["name"] = humanize_effect_name(str(scene.resource_path.get_file().get_basename()))
    instance.free()
    return display


## Flavor line always names the actual trigger. Stale "when triggered"
## descriptions are rewritten with the packed instance's trigger; clean
## descriptions without any trigger mention get a "(Triggers on X)" suffix
## so randomly generated triggers are always visible. Descriptions that
## already name a trigger are left untouched to avoid duplication.
static func _flavor_with_trigger(flavor: String, item: Item) -> String:
    var trigger := ""
    if has_effect_scene(item):
        trigger = peek_packed_trigger(item.effect_scene[0])
    if trigger.is_empty():
        return flavor
    var named := humanize_trigger(trigger)
    if "when triggered" in flavor:
        return flavor.replace("when triggered", "on " + named)
    if "riggers on" in flavor:
        return flavor
    return "%s (Triggers on %s)" % [flavor, named]


static func peek_packed_trigger(scene: PackedScene) -> String:
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


## Humanize event names for display: "on_hit" -> "hit" (avoids the
## "Triggers on on hit" doubling), "before_take_damage" -> "before take damage".
static func humanize_trigger(trigger: String) -> String:
    var s := trigger.strip_edges()
    if s.begins_with("on_"):
        s = s.substr(3)
    return s.replace("_", " ").strip_edges()


static func peek_packed_modifiers(scene: PackedScene) -> Dictionary:
    if scene == null:
        return {}
    var instance: Node = scene.instantiate()
    if instance == null:
        return {}
    var payload := {}
    for p in instance.get_property_list():
        if p.name == "modifiers":
            var value = instance.get("modifiers")
            if typeof(value) == TYPE_DICTIONARY:
                payload = (value as Dictionary).duplicate()
            break
    instance.free()
    return payload


static func humanize_effect_name(raw: String) -> String:
    var s := raw.strip_edges().replace("_", " ").replace("-", " ")
    if s.is_empty():
        return ""
    # Drop generic suffixes so `ProjectileBounceModifier` -> `Projectile Bounce`.
    for suffix in ["Modifier", "Effect"]:
        if s.ends_with(suffix) and s.length() > suffix.length():
            s = s.substr(0, s.length() - suffix.length()).strip_edges()
            break
    # Split PascalCase / camelCase on lower->Upper boundaries.
    var spaced := ""
    for i in range(s.length()):
        var c := s[i]
        if i > 0 and s[i - 1] != " " and _is_upper(c) and _is_lower(s[i - 1]):
            spaced += " "
        spaced += c
    # Title-case each word for a stable human-readable noun.
    var words := spaced.split(" ", false)
    for i in range(words.size()):
        words[i] = words[i].capitalize()
    return " ".join(words)


static func _is_upper(c: String) -> bool:
    return c == c.to_upper() and c != c.to_lower()


static func _is_lower(c: String) -> bool:
    return c == c.to_lower() and c != c.to_upper()
