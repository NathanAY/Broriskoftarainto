extends IconCard
class_name CharacterCard

## Compact grid entry for the character selection screen: icon + name only.
## The tile itself is the shared `IconCard`; this class adds the click handling
## and the selection highlight. Full stats for the chosen character go in the
## top `CharacterDetailPanel`, which is the same `ItemDisplayPanel` the shop card
## uses.

signal selected(card: CharacterCard)

## Shared with the shop card's hover, so the two screens highlight the same way.
const SELECTED_BORDER := Color(0.976471, 0.729412, 0.313726, 1)

var character: CharacterData = null
var character_path: String = ""
var is_selected: bool = false


func _ready() -> void:
	super()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)
	_apply_selection_visual()


func set_character_display(p_path: String, p_character: CharacterData) -> void:
	character_path = p_path
	character = p_character
	if not is_node_ready():
		return
	if character == null:
		name_label.text = "Unknown"
		return
	set_display(character)


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
	var accent := SELECTED_BORDER if is_selected else ItemDisplayPanel.PANEL_BORDER
	set_border_color(accent)
	set_name_color(SELECTED_BORDER if is_selected else ItemDisplayPanel.COLOR_NEUTRAL)
