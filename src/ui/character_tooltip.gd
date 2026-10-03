extends RefCounted
class_name CharacterTooltip

## Static builder of tooltip-style key-value lines for CharacterData.
## Mirrors ItemTooltip formatting so character cards read like ShopItemCard:
## one fact per line, joined with "\n\n" by the card.


static func tooltip_lines(character: CharacterData) -> PackedStringArray:
	var lines := PackedStringArray()
	if character == null:
		return lines
	lines.append("name: " + str(character.display_name))
	var description := str(character.description).strip_edges()
	if not description.is_empty():
		lines.append(description)
	for stat_name in character.base_stats.keys():
		lines.append("base %s: %s" % [str(stat_name), str(character.base_stats[stat_name])])
	for mod in character.modifiers:
		# `modifiers` holds two entry kinds (see CharacterData): stat dicts
		# render as "<stat> <kind>: <value>", modifier scenes render as an
		# "effect:" line built from the scene's own display contract.
		if mod is PackedScene:
			for line in _effect_lines(mod):
				lines.append(line)
			continue
		if typeof(mod) != TYPE_DICTIONARY:
			continue
		for line in ItemTooltip.modifier_lines(mod):
			lines.append(line)
	for item in character.starting_items:
		if item == null:
			continue
		var item_name := str(item.name) if "name" in item else str(item)
		lines.append("starting item: " + item_name)
	for weapon in character.starting_weapons:
		if weapon == null:
			continue
		var weapon_name := str(weapon.name) if "name" in weapon else str(weapon)
		lines.append("starting weapon: " + weapon_name)
	return lines


## Structured counterpart of `tooltip_lines()`, used by the character select
## panel so each line can be coloured and get its own stat icon. The flat text
## version above is left untouched and still serves the hover tooltip.
static func card_rows(character: CharacterData) -> Array:
	var rows: Array = []
	if character == null:
		return rows
	_append_name_row(rows, character)
	_append_flavor_row(rows, character)
	_append_base_stat_rows(rows, character)
	_append_modifier_rows(rows, character)
	_append_starting_rows(rows, character)
	return rows


static func _append_name_row(rows: Array, character: CharacterData) -> void:
	var row := ItemCardRow.new()
	row.kind = ItemCardRow.Kind.NAME
	row.label = str(character.display_name)
	rows.append(row)


static func _append_flavor_row(rows: Array, character: CharacterData) -> void:
	var description := str(character.description).strip_edges()
	if description.is_empty() or not ItemTooltip.is_clean_flavor(description):
		return
	var row := ItemCardRow.new()
	row.kind = ItemCardRow.Kind.FLAVOR
	row.text = description
	rows.append(row)


## `base_stats` are absolute values that replace the Stats defaults, not gains.
## The value is shown as-is; the tone says whether it beats the default, so a
## 120 HP character reads green against the 10 HP norm and a 5 HP one red.
static func _append_base_stat_rows(rows: Array, character: CharacterData) -> void:
	for stat_name in character.base_stats.keys():
		var key := str(stat_name)
		var value = character.base_stats[stat_name]
		var row := ItemCardRow.new()
		row.kind = ItemCardRow.Kind.STAT
		row.stat_name = key
		row.icon = Stats.get_stat_icon(key)
		row.label = ItemTooltip.humanize_effect_name(key)
		row.value = ItemTooltip.format_value(value)
		row.tone = _tone_vs_default(row.value, Stats.default_stat(key))
		rows.append(row)


## The value itself is a real stat value, not a modifier delta, so it carries no
## "+" prefix - the colour already carries the meaning.
static func _tone_vs_default(shown: String, default_value: float) -> ItemCardRow.Tone:
	var number := String(shown).to_float()
	if number > default_value:
		return ItemCardRow.Tone.POSITIVE
	if number < default_value:
		return ItemCardRow.Tone.NEGATIVE
	return ItemCardRow.Tone.NEUTRAL


static func _append_modifier_rows(rows: Array, character: CharacterData) -> void:
	for mod in character.modifiers:
		if mod is PackedScene:
			var effect := _effect_row(mod)
			if effect != null:
				rows.append(effect)
			continue
		if typeof(mod) != TYPE_DICTIONARY:
			continue
		# Deltas, so they keep the explicit "+" the shop card uses.
		for row in ItemTooltip.stat_rows(mod):
			rows.append(row)


static func _append_starting_rows(rows: Array, character: CharacterData) -> void:
	for item in character.starting_items:
		if item == null:
			continue
		rows.append(_gear_row("Starting Item", str(item.name) if "name" in item else str(item)))
	for weapon in character.starting_weapons:
		if weapon == null:
			continue
		rows.append(_gear_row("Starting Weapon", str(weapon.name) if "name" in weapon else str(weapon)))


static func _gear_row(label: String, value: String) -> ItemCardRow:
	var row := ItemCardRow.new()
	row.kind = ItemCardRow.Kind.GEAR
	row.label = label
	row.value = value
	return row


static func _effect_row(scene: PackedScene) -> ItemCardRow:
	var head := _effect_head(scene)
	if head.is_empty():
		return null
	var row := ItemCardRow.new()
	row.kind = ItemCardRow.Kind.EFFECT
	row.text = head
	return row


## One `effect:` line per modifier scene a character declares, formatted from the
## modifier's own display fields (name / text / stats / trigger) so a character
## card shows the same wording as the shop item that grants the same modifier.
static func _effect_lines(scene: PackedScene) -> PackedStringArray:
	var lines := PackedStringArray()
	var head := _effect_head(scene)
	if not head.is_empty():
		lines.append("effect: " + head)
	return lines


## Shared by `tooltip_lines()` and `card_rows()` so the flat text and the
## coloured card can never drift apart in wording.
static func _effect_head(scene: PackedScene) -> String:
	var display: Dictionary = ItemTooltip.resolve_effect_display(scene)
	var effect_name := str(display.get("name", ""))
	if effect_name.is_empty():
		return ""
	var head := effect_name
	var body_parts := PackedStringArray()
	for key in ["text", "stats"]:
		var value := str(display.get(key, ""))
		if not value.is_empty():
			body_parts.append(value)
	if body_parts.size() > 0:
		head += " — " + " ".join(body_parts)
	var trigger := str(display.get("trigger", ""))
	if not trigger.is_empty():
		head += " (Triggers on %s)" % ItemTooltip.humanize_trigger(trigger)
	return head
