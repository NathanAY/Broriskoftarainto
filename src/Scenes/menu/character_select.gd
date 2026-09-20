extends CanvasLayer

@onready var chars_container: GridContainer = $Control/VBoxContainer/ScrollContainer/CharsList
@onready var details_icon_holder: CenterContainer = $Control/VBoxContainer/DetailPanel/Margin/HBox/DetailIconHolder
@onready var details_label: Label = $Control/VBoxContainer/DetailPanel/Margin/HBox/DetailVBox/TopScrollContainer/Details
@onready var confirm_button: Button = $Control/VBoxContainer/HBoxContainer/Confirm
@onready var cancel_button: Button = $Control/VBoxContainer/HBoxContainer/Cancel
@onready var tooltip: TooltipUi = $Tooltip

const CHARACTER_CARD_SCENE: PackedScene = preload("res://src/Scenes/menu/CharacterCard.tscn")
const DETAIL_ICON_SIZE := Vector2(96, 96)

var characters: Array = [] # list of (path, resource)
var selected_path = null
var cards: Array[CharacterCard] = []
var selected_card: CharacterCard = null


func _ready():
    _load_characters("res://src/Assets/character", chars_container)
    confirm_button.pressed.connect(_on_confirm_pressed)
    cancel_button.pressed.connect(_on_cancel_pressed)
    if cards.size() > 0:
        _on_card_selected(cards[0])


func _load_characters(base_path: String, container: GridContainer):
    var dir = DirAccess.open(base_path)
    if not dir:
        push_error("Could not open " + base_path)
        return

    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
        if dir.current_is_dir():
            if not file_name.begins_with("."): # Skip hidden folders like .
                _load_characters(base_path.path_join(file_name), container)
        if not dir.current_is_dir() and file_name.ends_with(".tres"):
            var path = base_path + "/" + file_name
            var res: CharacterData = load(path)
            if res == null:
                file_name = dir.get_next()
                continue
            var card: CharacterCard = CHARACTER_CARD_SCENE.instantiate()
            container.add_child(card)
            card.set_character_display(path, res)
            card.selected.connect(_on_card_selected)
            tooltip.bind_to_row(card, res)
            cards.append(card)
            characters.append([path, res])
        file_name = dir.get_next()
    dir.list_dir_end()


func _on_card_selected(card: CharacterCard) -> void:
    _on_character_pressed(card.character_path, card.character, card)


func _on_character_pressed(path: String, res: CharacterData, card: CharacterCard = null):
    selected_path = path
    selected_card = card
    for c in cards:
        c.set_selected(c == card)
    if res:
        _update_details(res)


## Full stats view for the selected character, using the same
## CharacterTooltip formatting the grid cards used to show inline.
func _update_details(res: CharacterData) -> void:
    for child in details_icon_holder.get_children():
        child.free()
    var icon := TextureRect.new()
    if res.small_icon:
        icon.texture = res.small_icon
    elif res.sprite:
        icon.texture = res.sprite
    elif ResourceLoader.exists("res://src/Assets/character/potato.png"):
        icon.texture = load("res://src/Assets/character/potato.png")
    icon.custom_minimum_size = DETAIL_ICON_SIZE
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    details_icon_holder.add_child(icon)
    details_label.text = "\n\n".join(CharacterTooltip.tooltip_lines(res))


func _on_confirm_pressed():
    if not selected_path:
        return
    GlobalGameState.starting_character = selected_path
    get_tree().change_scene_to_file("res://src/Scenes/menu/StarterMenu.tscn")


func _on_cancel_pressed():
    get_tree().change_scene_to_file("res://src/Scenes/menu/StarterMenu.tscn")
