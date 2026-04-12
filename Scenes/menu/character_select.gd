extends CanvasLayer

@onready var chars_container: GridContainer = $Control/VBoxContainer/ScrollContainer/CharsList
@onready var details_label: Label = $Control/VBoxContainer/TopScrollContainer/Details
@onready var confirm_button: Button = $Control/VBoxContainer/HBoxContainer/Confirm
@onready var cancel_button: Button = $Control/VBoxContainer/HBoxContainer/Cancel


var characters: Array = [] # list of (path, resource)
var selected_path = null

func _ready():
    _load_characters("res://Assets/character", chars_container)
    confirm_button.pressed.connect(_on_confirm_pressed)
    cancel_button.pressed.connect(_on_cancel_pressed)

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
            var display_name = "Unknown"
            if res and res.display_name:
                display_name = res.display_name

            var char_name_and_icon: VSplitContainer = VSplitContainer.new()
            var btn: TextureButton = TextureButton.new()
            btn.texture_normal = res.small_icon
            btn.pressed.connect(func(p=path, r=res): _on_character_pressed(p, r))
            var btn_txt: Button = Button.new()
            btn_txt.text = res.display_name
            btn_txt.pressed.connect(func(p=path, r=res): _on_character_pressed(p, r))

            char_name_and_icon.add_child(btn)
            char_name_and_icon.add_child(btn_txt)
            container.add_child(char_name_and_icon)
            characters.append([path, res])
        file_name = dir.get_next()
    dir.list_dir_end()

func _on_character_pressed(path: String, res: CharacterData):
    selected_path = path
    if res:
        var s = "{0}\n\n".format([res.display_name])
        s += res.description + "\n\n"
        s += "Base stats:\n"
        for k in res.base_stats.keys():
            s += "{0}: {1}\n".format([k, str(res.base_stats[k])])
        if res.modifiers.size() > 0:
            s += "\nModifiers:\n"
            for m in res.modifiers:
                s += str(m) + "\n"
        if res.starting_items.size() > 0:
            s += "\nStarting Items:\n"
            for item in res.starting_items:
                s += str(item) + "\n"
        details_label.text = s

func _on_confirm_pressed():
    if not selected_path:
        return
    GlobalGameState.starting_character = selected_path
    get_tree().change_scene_to_file("res://Scenes/menu/StarterMenu.tscn")

func _on_cancel_pressed():
    get_tree().change_scene_to_file("res://Scenes/menu/StarterMenu.tscn")
