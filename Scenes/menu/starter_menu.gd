extends CanvasLayer

@onready var weapons_container: VBoxContainer = $Control/VBoxContainer/Weapons/ChooseScroll/SelectList
@onready var items_container: VBoxContainer = $Control/VBoxContainer/Items/ChooseScroll/SelectList
@onready var selected_weapons_list: ItemList = $Control/VBoxContainer/Weapons/ResultScroll/ResultList
@onready var selected_items_list: ItemList = $Control/VBoxContainer/Items/ResultScroll/ResultList
@onready var clear_button: Button = $Control/VBoxContainer/HBoxContainer/Clear
@onready var play_button: Button = $Control/VBoxContainer/HBoxContainer/Play

var selected_weapons: Array[String] = []
var selected_items: Array[String] = []

func _ready():
    _load_resource_buttons("res://Resources/weapons", weapons_container, func(path, name): _add_weapon(path, name))
    _load_resource_buttons("res://Resources/items", items_container, func(path, name): _add_item(path, name))
    clear_button.pressed.connect(_clear_all)
    play_button.pressed.connect(_on_play_pressed)

func _load_resource_buttons(base_path: String, container: VBoxContainer, callback: Callable):
    var dir = DirAccess.open(base_path)
    if not dir:
        push_error("Could not open " + base_path)
        return

    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
        if not dir.current_is_dir() and file_name.ends_with(".tres"):
            var path = base_path + "/" + file_name
            var res: Resource = load(path)
            var display_name := file_name.get_basename() # or res.name if defined

            var btn = Button.new()
            btn.text = "Add " + display_name
            btn.pressed.connect(func(): callback.call(path, display_name))
            container.add_child(btn)
        file_name = dir.get_next()
    dir.list_dir_end()

func _add_weapon(path: String, display_name: String):
    selected_weapons.append(path)
    selected_weapons_list.add_item(display_name)

func _add_item(path: String, display_name: String):
    selected_items.append(path)
    selected_items_list.add_item(display_name)

func _clear_all():
    selected_weapons.clear()
    selected_items.clear()
    selected_weapons_list.clear()
    selected_items_list.clear()

func _on_play_pressed():
    if selected_weapons.is_empty() and selected_items.is_empty():
        return # prevent starting without anything

    GlobalGameState.starting_weapons = selected_weapons.duplicate()
    GlobalGameState.starting_items = selected_items.duplicate()
    get_tree().change_scene_to_file("res://Scenes/Game.tscn")
