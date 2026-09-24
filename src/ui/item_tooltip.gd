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
    if not has_effect_scene(item):
        return
    var display: Dictionary = resolve_effect_display_for_item(item, item.effect_scene[0])
    var effect_name := str(display.get("name", ""))
    if effect_name.is_empty():
        return
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
    lines.append("effect: " + head)


static func _append_buff_debuff_lines(lines: PackedStringArray, item: Item, prefix: String) -> void:
    lines.append("name: " + str(item.name))
    var flavor := str(item.description)
    if not flavor.is_empty() and is_clean_flavor(flavor):
        lines.append(_flavor_with_trigger(flavor, item))
    var payload := peek_packed_modifiers(item.effect_scene[0] if has_effect_scene(item) else null)
    for line in modifier_lines(payload):
        lines.append(prefix + ": " + line)
    _append_tradeoff_lines(lines, item.modifiers)


static func is_clean_flavor(description: String) -> bool:
    # Transitional guard: old factory descriptions embedded raw dicts ("{...}").
    # Clean flavor (flavor + trigger only) never contains braces.
    return not ("{" in description or "}" in description)


## Steady state (Q8-C): prefer build-time resolved values stored on the item;
## fallback (Q8-A): temp instantiate, read contract fields, free, cache per path.
static func resolve_effect_display_for_item(item: Item, scene: PackedScene) -> Dictionary:
    if item != null and item.has_meta("effect_display_name"):
        return {
            "name": str(item.get_meta("effect_display_name")),
            "text": str(item.get_meta("effect_tooltip_text")) if item.has_meta("effect_tooltip_text") else "",
            "stats": str(item.get_meta("effect_tooltip_stats")) if item.has_meta("effect_tooltip_stats") else "",
            "trigger": str(item.get_meta("effect_trigger")) if item.has_meta("effect_trigger") else "",
        }
    return resolve_effect_display(scene)


static func resolve_effect_display(scene: PackedScene) -> Dictionary:
    var empty := {"name": "", "text": "", "stats": "", "trigger": ""}
    if scene == null:
        return empty.duplicate()
    var path := str(scene.resource_path)
    if not path.is_empty() and _effect_display_cache.has(path):
        return (_effect_display_cache[path] as Dictionary).duplicate()
    var display := _read_display_from_scene(scene)
    if not path.is_empty() and not str(display.get("name", "")).is_empty():
        _effect_display_cache[path] = display.duplicate()
    return display


static func _read_display_from_scene(scene: PackedScene) -> Dictionary:
    var display := {"name": "", "text": "", "stats": "", "trigger": ""}
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
