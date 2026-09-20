# GdUnit TestSuite for the compact CharacterCard and the CharacterSelect detail panel.
class_name CharacterCardGdUnit4Test
extends GdUnitTestSuite

const CARD_SCENE := "res://src/Scenes/menu/CharacterCard.tscn"
const SELECT_SCENE := "res://src/Scenes/menu/CharacterSelect.tscn"
const SOLDIER := "res://src/Assets/character/soldier/Soldier.tres"


func test_tooltip_lines_cover_name_stats_modifiers_items() -> void:
	var res: CharacterData = load(SOLDIER)
	var lines := CharacterTooltip.tooltip_lines(res)
	assert_str("\n".join(lines)).contains("name: Soldier")
	assert_str("\n".join(lines)).contains("Slow and sturdy")
	assert_str("\n".join(lines)).contains("base health: 120")
	assert_str("\n".join(lines)).contains("armor flat: 2")
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
	assert_bool(card.modulate == Color(1.0, 0.9, 0.6)).is_true()

	card.set_selected(false)
	assert_bool(card.is_selected).is_false()
	assert_bool(card.modulate == Color.WHITE).is_true()

	card.free()


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
	assert_str(menu.details_name.text).is_equal(str(second.character.display_name))
	assert_str(menu.details_label.text).is_equal("\n\n".join(CharacterTooltip.tooltip_lines(second.character)))
	assert_int(menu.details_icon_holder.get_child_count()).is_equal(1)

	menu.free()


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
	var expected: String = "\n".join(ItemTooltip.tooltip_lines(hovered.character))
	assert_str(menu.tooltip.label.text).is_equal(expected)
	assert_str(menu.tooltip.label.text).contains("name: " + str(hovered.character.display_name))
	if hovered.character.starting_items.size() > 0:
		assert_str(menu.tooltip.label.text).contains("starting item:")
	else:
		assert_str(menu.tooltip.label.text).contains("base ")

	# Leaving hides the tooltip and never changes the selection.
	hovered.mouse_exited.emit()
	assert_bool(menu.tooltip.visible).is_false()
	assert_str(menu.selected_path).is_equal(selected_before)
	assert_bool(hovered.is_selected).is_false()

	menu.free()
