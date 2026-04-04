extends CanvasLayer

@onready var chars_container: VBoxContainer = $Control/VBoxContainer/CharsList
@onready var details_label: Label = $Control/VBoxContainer/Details
@onready var confirm_button: Button = $Control/VBoxContainer/HBoxContainer/Confirm
@onready var cancel_button: Button = $Control/VBoxContainer/HBoxContainer/Cancel


var characters: Array = [] # list of (path, resource)
var selected_path = null

func _ready():
    _load_characters("res://Resources/characters", chars_container)
    confirm_button.pressed.connect(_on_confirm_pressed)
    cancel_button.pressed.connect(_on_cancel_pressed)

func _load_characters(base_path: String, container: VBoxContainer):
    var dir = DirAccess.open(base_path)
    if not dir:
        push_error("Could not open " + base_path)
        return

    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
        if not dir.current_is_dir() and file_name.ends_with(".tres"):
            var path = base_path + "/" + file_name
            var res = load(path)
            var display_name = "Unknown"
            if res and res.display_name:
                display_name = res.display_name

            var btn = Button.new()
            btn.text = display_name
            btn.pressed.connect(func(p=path, r=res): _on_character_pressed(p, r))
            container.add_child(btn)
            characters.append([path, res])
        file_name = dir.get_next()
    dir.list_dir_end()

func _on_character_pressed(path: String, res):
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
        details_label.text = s

func _on_confirm_pressed():
    if not selected_path:
        return
    GlobalGameState.starting_character = selected_path
    get_tree().change_scene_to_file("res://Scenes/menu/StarterMenu.tscn")

func _on_cancel_pressed():
    get_tree().change_scene_to_file("res://Scenes/menu/StarterMenu.tscn")
