# GdUnit TestSuite for the compact CharacterCard and the CharacterSelect detail panel.
class_name CharacterCardTest
extends GdUnitTestSuite

const CARD_SCENE := "res://src/Scenes/menu/CharacterCard.tscn"
const SELECT_SCENE := "res://src/Scenes/menu/CharacterSelect.tscn"
const DETAIL_SCENE := "res://src/ui/CharacterDetailPanel.tscn"
const SOLDIER := "res://src/Assets/character/soldier/Soldier.tres"


func test_tooltip_lines_cover_name_stats_modifiers_items() -> void:
	var res: CharacterData = load(SOLDIER)
	var lines := CharacterTooltip.tooltip_lines(res)
	assert_str("\n".join(lines)).contains("name: Soldier")
	assert_str("\n".join(lines)).contains("Slow and sturdy")
	assert_str("\n".join(lines)).contains("base health: 120")
	assert_str("\n".join(lines)).contains("armor flat: 12")
	assert_str("\n".join(lines)).contains("starting item:")


func test_item_tooltip_supports_character_data() -> void:
	var res: CharacterData = load(SOLDIER)
	var lines := ItemTooltip.tooltip_lines(res)
	assert_str("\n".join(lines)).is_equal("\n".join(CharacterTooltip.tooltip_lines(res)))
	assert_str("\n".join(lines)).contains("name: Soldier")
	assert_str("\n".join(lines)).contains("base health: 120")


func test_card_is_compact_icon_and_name_only() -> void:
	var card: CharacterCard = load(CARD_SCENE).instantiate()
	add_child(card)
	var res: CharacterData = load(SOLDIER)
	card.set_character_display(SOLDIER, res)

	assert_that(card).is_not_null()
	# Compact enough to fit 30+ characters on one screen.
	assert_bool(card.custom_minimum_size.x <= 160.0).is_true()
	assert_bool(card.custom_minimum_size.y <= 160.0).is_true()
	assert_that(card.get_node("Margin/VBox/IconHolder")).is_not_null()
	assert_that(card.get_node("Margin/VBox/NameLabel")).is_not_null()

	# Full stats moved to the top detail panel, not on the card.
	assert_bool(card.has_node("Margin/VBox/InfoScroll")).is_false()
	assert_bool(card.has_node("Margin/VBox/Buttons")).is_false()

	assert_str(card.name_label.text).is_equal("Soldier")
	assert_int(card.icon_holder.get_child_count()).is_equal(1)

	card.free()


func test_card_click_selects_and_highlights() -> void:
	var card: CharacterCard = load(CARD_SCENE).instantiate()
	add_child(card)
	var res: CharacterData = load(SOLDIER)
	card.set_character_display(SOLDIER, res)

	# Clicking the card emits selected.
	var clicked: Array = []
	card.selected.connect(func(c): clicked.append(c))
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	card.gui_input.emit(mb)
	assert_int(clicked.size()).is_equal(1)
	assert_that(clicked[0]).is_same(card)

	# Highlight only changes modulate, no buttons on the compact card.
	card.set_selected(true)
	assert_bool(card.is_selected).is_true()
	assert_bool(card.get_theme_stylebox("panel").border_color == CharacterCard.SELECTED_BORDER).is_true()

	card.set_selected(false)
	assert_bool(card.is_selected).is_false()
	assert_bool(card.get_theme_stylebox("panel").border_color == ItemDisplayPanel.PANEL_BORDER).is_true()

	card.free()


func test_card_uses_the_shared_panel_palette() -> void:
	var card: CharacterCard = load(CARD_SCENE).instantiate()
	add_child(card)

	var style: StyleBoxFlat = card.get_theme_stylebox("panel")
	assert_that(style).is_not_null()
	# Same background, radius and border weight as ShopItemCard / TooltipUi, so
	# the grid reads as part of the same UI kit rather than a bolted-on widget.
	assert_bool(style.bg_color == ItemDisplayPanel.PANEL_BG).is_true()
	assert_int(style.corner_radius_top_left).is_equal(ItemDisplayPanel.PANEL_RADIUS)
	assert_int(style.border_width_left).is_equal(2)

	card.free()


func test_grid_row_is_ten_wide_for_many_characters() -> void:
	var menu = load(SELECT_SCENE).instantiate()
	add_child(menu)

	var grid: GridContainer = menu.get_node("Control/VBoxContainer/ScrollContainer/CharsList")
	# Ten per row so 15+ characters still fit on one screen.
	assert_int(grid.columns).is_equal(10)
	# Extra rows scroll instead of pushing the buttons off screen.
	var scroll: ScrollContainer = menu.get_node("Control/VBoxContainer/ScrollContainer")
	assert_int(scroll.vertical_scroll_mode).is_equal(ScrollContainer.SCROLL_MODE_AUTO)

	menu.free()


func test_character_select_uses_compact_cards_and_detail_panel() -> void:
	var menu = load(SELECT_SCENE).instantiate()
	add_child(menu)

	var container: GridContainer = menu.get_node("Control/VBoxContainer/ScrollContainer/CharsList")
	assert_int(container.get_child_count()).is_greater(0)
	for child in container.get_children():
		assert_that(child is CharacterCard).is_true()
		assert_bool((child as CharacterCard).custom_minimum_size.x <= 160.0).is_true()

	# First character is pre-selected so the detail panel is never empty.
	assert_str(menu.selected_path).is_not_empty()
	assert_that(menu.selected_card).is_not_null()
	assert_bool(menu.selected_card.is_selected).is_true()

	# Selecting another card fills the top detail panel with full stats.
	var second: CharacterCard = container.get_child(1)
	second.select()

	assert_str(menu.selected_path).is_equal(second.character_path)
	assert_bool(second.is_selected).is_true()
	# The top panel is the shared card base, not a hand-rolled label.
	assert_that(menu.details_panel).is_instanceof(ItemDisplayPanel)
	assert_str(menu.details_panel.name_label.text).is_equal(second.character.display_name)
	assert_str(menu.details_panel.info_label.text).contains("Health")
	assert_int(menu.details_panel.icon_holder.get_child_count()).is_equal(1)

	menu.free()


# --- top detail panel -------------------------------------------------------

func test_top_panel_is_the_shared_item_display_panel() -> void:
	var menu = load(SELECT_SCENE).instantiate()
	add_child(menu)

	# Same node skeleton as ShopItemCard, so the two screens cannot drift apart.
	var panel: ItemDisplayPanel = menu.details_panel
	for path in ["Margin/VBox/Header/IconPlate/IconHolder", "Margin/VBox/Header/NameBox/NameLabel",
			"Margin/VBox/Separator", "Margin/VBox/InfoScroll/InfoLabel"]:
		assert_that(panel.get_node_or_null(path)).is_not_null()

	# Characters are not weapons: no weapon badge.
	panel.set_resource(load(SOLDIER))
	assert_bool(panel.type_badge.visible).is_false()

	menu.free()


func test_base_stat_tone_follows_the_stats_default() -> void:
	var panel = load(DETAIL_SCENE).instantiate()
	add_child(panel)

	# Soldier has 120 health against a default of 10: a gain, so it is positive.
	var soldier: CharacterData = load(SOLDIER)
	panel.set_resource(soldier)
	var health := _row_for(panel, "Health")
	assert_that(health).is_not_null()
	assert_str(health.value).is_equal("120")
	assert_int(health.tone).is_equal(ItemCardRow.Tone.POSITIVE)

	# A character below the default reads as a loss.
	var frail := CharacterData.new()
	frail.display_name = "Frail"
	frail.base_stats = {"health": 5.0}
	panel.set_resource(frail)
	var frail_health := _row_for(panel, "Health")
	assert_int(frail_health.tone).is_equal(ItemCardRow.Tone.NEGATIVE)

	# Exactly the default is neither a gain nor a loss.
	var plain := CharacterData.new()
	plain.display_name = "Plain"
	plain.base_stats = {"health": Stats.default_stat("health")}
	panel.set_resource(plain)
	assert_int(_row_for(panel, "Health").tone).is_equal(ItemCardRow.Tone.NEUTRAL)

	panel.free()


func test_character_rows_cover_stats_modifiers_and_gear() -> void:
	var soldier: CharacterData = load(SOLDIER)
	var rows := ItemTooltip.card_rows(soldier)
	var labels := PackedStringArray()
	for row in rows:
		labels.append((row as ItemCardRow).to_line())

	assert_str("\n".join(labels)).contains("name: Soldier")
	assert_str("\n".join(labels)).contains("Slow and sturdy")
	assert_str("\n".join(labels)).contains("Health: 120")
	assert_str("\n".join(labels)).contains("Armor: +12")
	# Effect and gear rows render as prose / "Label: value", not "key: value".
	assert_str("\n".join(labels)).contains("Armor — Armor reduces incoming damage.")
	assert_str("\n".join(labels)).contains("Starting Item: Passive regen")

	# `tooltip_lines()` is the flat contract and must stay byte-identical.
	assert_str("\n".join(ItemTooltip.tooltip_lines(soldier))).is_equal(
		"\n".join(CharacterTooltip.tooltip_lines(soldier)))


func _row_for(panel: ItemDisplayPanel, label: String) -> ItemCardRow:
	for row in ItemTooltip.card_rows(panel.item):
		var typed: ItemCardRow = row
		if typed.label == label:
			return typed
	return null


func test_card_hover_shows_full_details_without_selecting() -> void:
	var menu = load(SELECT_SCENE).instantiate()
	add_child(menu)

	var container: GridContainer = menu.get_node("Control/VBoxContainer/ScrollContainer/CharsList")
	var hovered: CharacterCard = container.get_child(1)
	var selected_before: String = menu.selected_path
	assert_bool(hovered.character_path != selected_before).is_true()

	# Hovering shows every character detail in the shared tooltip.
	assert_bool(menu.tooltip.visible).is_false()
	hovered.mouse_entered.emit()
	assert_bool(menu.tooltip.visible).is_true()

	# The name lives in the tooltip header, not as a "name:" line in the body,
	# and the body is the same coloured row set the detail panel renders.
	assert_str(menu.tooltip.name_label.text).is_equal(str(hovered.character.display_name))
	var expected_body: String = ItemDisplayPanel.build_bbcode(
		ItemTooltip.card_rows(hovered.character), hovered.character)
	assert_str(menu.tooltip.label.text).is_equal(expected_body)
	assert_bool(menu.tooltip.label.text.contains("name:")).is_false()
	assert_bool(menu.tooltip.label.text.contains("base health:")).is_false()
	# The character art is there, not just a text placeholder.
	assert_int(menu.tooltip.icon_holder.get_child_count()).is_equal(1)

	# Leaving hides the tooltip and never changes the selection.
	hovered.mouse_exited.emit()
	assert_bool(menu.tooltip.visible).is_false()
	assert_str(menu.selected_path).is_equal(selected_before)
	assert_bool(hovered.is_selected).is_false()

	menu.free()
