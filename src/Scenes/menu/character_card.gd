extends PanelContainer
class_name CharacterCard

## Compact grid entry for the character selection screen: icon + name only.
## The whole card is clickable and emits `selected`; full stats for the chosen
## character go in the top `CharacterDetailPanel`, which is the same
## `ItemDisplayPanel` the shop card uses.
##
## It is not an ItemDisplayPanel subclass - it has no body - but it borrows that
## class's palette and panel styling so the grid reads as part of the same UI.

signal selected(card: CharacterCard)

## Shared with the shop card's hover, so the two screens highlight the same way.
const SELECTED_BORDER := Color(0.976471, 0.729412, 0.313726, 1)

@onready var icon_holder: CenterContainer = $Margin/VBox/IconHolder
@onready var name_label: Label = $Margin/VBox/NameLabel

var character: CharacterData = null
var character_path: String = ""
var is_selected: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)
	_apply_selection_visual()


func set_character_display(p_path: String, p_character: CharacterData) -> void:
	character_path = p_path
	character = p_character
	_clear_icon()
	if not is_node_ready():
		return
	if character == null:
		name_label.text = "Unknown"
		return
	icon_holder.add_child(ItemDisplayPanel.make_icon(character))
	# The icon is decorative; the card itself handles the hover.
	ItemDisplayPanel.set_mouse_ignore(icon_holder)
	name_label.text = ItemDisplayPanel.display_name(character)


func set_selected(p_selected: bool) -> void:
	is_selected = p_selected
	_apply_selection_visual()


func select() -> void:
	selected.emit(self)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			select()


## Selection is a border and a name colour, not a `modulate` tint: tinting the
## whole card also recolours the character's own art.
func _apply_selection_visual() -> void:
	if not is_node_ready():
		return
	var border := SELECTED_BORDER if is_selected else ItemDisplayPanel.PANEL_BORDER
	add_theme_stylebox_override("panel", ItemDisplayPanel.make_panel_stylebox(border))
	name_label.add_theme_color_override(
		"font_color", SELECTED_BORDER if is_selected else ItemDisplayPanel.COLOR_NEUTRAL)


func _clear_icon() -> void:
	if not is_node_ready():
		return
	# Immediate free, not queued: a re-display must not stack icons in the holder.
	for child in icon_holder.get_children():
		child.free()

