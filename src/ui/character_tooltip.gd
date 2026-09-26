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


## One `effect:` line per modifier scene a character declares, formatted from the
## modifier's own display fields (name / text / stats / trigger) so a character
## card shows the same wording as the shop item that grants the same modifier.
static func _effect_lines(scene: PackedScene) -> PackedStringArray:
	var lines := PackedStringArray()
	var display: Dictionary = ItemTooltip.resolve_effect_display(scene)
	var effect_name := str(display.get("name", ""))
	if effect_name.is_empty():
		return lines
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
	lines.append("effect: " + head)
	return lines
