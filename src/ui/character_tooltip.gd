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
		if typeof(mod) != TYPE_DICTIONARY:
			continue
		for line in ItemTooltip.modifier_lines(mod):
			lines.append(line)
	for item in character.starting_items:
		if item == null:
			continue
		var item_name := str(item.name) if "name" in item else str(item)
		lines.append("starting item: " + item_name)
	return lines
