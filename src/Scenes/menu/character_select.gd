extends CanvasLayer

@onready var chars_container: GridContainer = $Control/VBoxContainer/ScrollContainer/CharsList
@onready var details_panel: CharacterDetailPanel = $Control/VBoxContainer/DetailPanel
@onready var confirm_button: Button = $Control/VBoxContainer/HBoxContainer/Confirm
@onready var cancel_button: Button = $Control/VBoxContainer/HBoxContainer/Cancel
@onready var tooltip: TooltipUi = $Tooltip

const CHARACTER_CARD_SCENE: PackedScene = preload("res://src/Scenes/menu/CharacterCard.tscn")

var characters: Array = [] # list of (path, resource)
var selected_path = null
var cards: Array[CharacterCard] = []
var selected_card: CharacterCard = null


func _ready():
    # Entry point of a new run: make sure the tree is not left paused by a
    # previous screen (run end screen pauses the tree).
    get_tree().paused = false
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


## Full stats view for the selected character. The panel is the shared
## `ItemDisplayPanel`, so it renders the same header and coloured stat rows as a
## shop card; the content comes from `ItemTooltip.card_rows()`.
func _update_details(res: CharacterData) -> void:
    details_panel.set_character_display(res)


func _on_confirm_pressed():
    if not selected_path:
        return
    GlobalGameState.starting_character = selected_path
    get_tree().change_scene_to_file("res://src/Scenes/menu/StarterMenu.tscn")


func _on_cancel_pressed():
    get_tree().change_scene_to_file("res://src/Scenes/menu/StarterMenu.tscn")
