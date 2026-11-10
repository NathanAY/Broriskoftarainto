class_name Gamepedia
extends CanvasLayer
## The in-game encyclopedia: characters, weapons, enemies and the effects an item can carry.
##
## Built in code so the main menu and the pause menu can both instance it with
## `Gamepedia.new()`. The content is `GamepediaData`; this script only lays it out.
##
## Every entry is an `IconCard` - the tile the character select screen and the
## character menu's Weapons grid use - beside its text, so the art is drawn the
## same way on every screen.

## Emitted by the Back button, after the panel hides itself.
signal closed

const ICON_CARD_SCENE: PackedScene = preload("res://src/ui/IconCard.tscn")
const COLOR_NEGATIVE := Color(0.9, 0.35, 0.35)

var tabs: TabContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 3
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.09, 0.11, 0.95)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)

	var column := VBoxContainer.new()
	margin.add_child(column)
	var title := Label.new()
	title.text = "Gamepedia"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	_fill_characters(_add_tab("Characters"))
	_fill_weapons(_add_tab("Weapons"))
	_fill_enemies(_add_tab("Enemies"))
	_fill_modifiers(_add_tab("Modifiers"))

	var back := UiMenuButton.new()
	back.text = "Back"
	back.pressed.connect(_on_back_pressed)
	column.add_child(back)


func _on_back_pressed() -> void:
	visible = false
	closed.emit()


## A scrolling list, already in the tree: an `IconCard` fills itself only once
## it is in the tree, so entries are added to a list that is attached.
func _add_tab(tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	tabs.add_child(scroll)
	return list


func _fill_characters(list: Container) -> void:
	for entry in GamepediaData.character_entries():
		var card := _add_entry(list, entry["description"], entry["rows"])
		card.set_display(entry["resource"])


func _fill_weapons(list: Container) -> void:
	for entry in GamepediaData.weapon_entries():
		var card := _add_entry(list, entry["description"], entry["rows"])
		card.set_display(entry["resource"])


func _fill_enemies(list: Container) -> void:
	for entry in GamepediaData.enemy_entries():
		var lines: Array = entry["rows"].duplicate()
		for weapon in entry["weapons"]:
			lines.append(["Attacks with", weapon["name"]])
			for row in weapon["rows"]:
				lines.append(["    " + row[0], row[1]])
		var card := _add_entry(list, "", lines)
		_set_texture_display(card, entry["texture"], entry["name"])


func _fill_modifiers(list: Container) -> void:
	for entry in GamepediaData.modifier_entries():
		var lines: Array = []
		if not entry["stats"].is_empty():
			lines.append(["", entry["stats"]])
		if not entry["trigger"].is_empty():
			lines.append(["Triggers on", entry["trigger"]])
		var card := _add_entry(list, entry["text"], lines)
		_set_texture_display(card, entry["texture"], entry["name"])
		if entry["cost"]:
			card.set_name_color(COLOR_NEGATIVE)


## A tile for art that is a bare texture (an enemy, an effect) rather than a
## resource `IconCard.set_display()` knows how to draw. Goes through the same
## compositor an item's effect icon does, so a source-resolution texture is
## mipmapped on the way down to the plate.
func _set_texture_display(card: IconCard, texture: Texture2D, display_name: String) -> void:
	card.set_icon(ItemIconGenerator.make_composite_icon([texture], IconCard.ICON_SIZE))
	card.set_card_name(display_name)


## One entry: an `IconCard` on the left (filled by the caller), the text on the
## right as a paragraph and then `[label, value]` lines. Returns the card.
func _add_entry(list: Container, description: String, lines: Array) -> IconCard:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	list.add_child(row)

	var card: IconCard = ICON_CARD_SCENE.instantiate()
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(card)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	if not description.is_empty():
		text.add_child(_label(description, ItemDisplayPanel.COLOR_NEUTRAL))
	for line in lines:
		var shown := str(line[1]) if str(line[0]).is_empty() else "%s: %s" % [line[0], line[1]]
		text.add_child(_label(shown, ItemDisplayPanel.COLOR_NEUTRAL))
	return card


func _label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	return label
