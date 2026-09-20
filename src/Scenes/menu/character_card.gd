extends PanelContainer
class_name CharacterCard

## Compact grid entry for the character selection screen: icon + name only.
## The whole card is clickable and emits `selected`; full stats for the
## chosen character are shown in the top details panel of CharacterSelect
## (built from CharacterTooltip lines, same formatting the card used before).

signal selected(card: CharacterCard)

const ICON_SIZE := Vector2(64, 64)

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
	var icon := TextureRect.new()
	icon.texture = _resolve_icon()
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.add_child(icon)
	name_label.text = str(character.display_name)


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


func _apply_selection_visual() -> void:
	if not is_node_ready():
		return
	if is_selected:
		modulate = Color(1.0, 0.9, 0.6)
	else:
		modulate = Color.WHITE


func _resolve_icon() -> Texture2D:
	if character != null:
		if character.small_icon:
			return character.small_icon
		if character.sprite:
			return character.sprite
	if ResourceLoader.exists("res://src/Assets/character/potato.png"):
		return load("res://src/Assets/character/potato.png")
	return null


func _clear_icon() -> void:
	if not is_node_ready():
		return
	for child in icon_holder.get_children():
		child.queue_free()
