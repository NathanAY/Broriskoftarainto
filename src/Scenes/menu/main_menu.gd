extends CanvasLayer

## Main menu: static background plus the button navigation.

## Dev-only shortcut into a run that is already mid/endgame. The picker and every
## scene it lists live in `test/scenarios/`, which is not shipped - hence the
## existence check rather than a straight scene change.
const DEBUG_SCENARIOS_SCENE := "res://test/scenarios/debug_scenario_menu.tscn"

@onready var new_game_button: Button = $Control/VBoxContainer/NewGameButton
@onready var debug_scenarios_button: Button = $Control/VBoxContainer/DebugScenariosButton
@onready var options_button: Button = $Control/VBoxContainer/OptionsButton
@onready var exit_button: Button = $Control/VBoxContainer/ExitButton

@onready var main_control: Control = $Control
@onready var options_menu: CanvasLayer = $OptionsMenu


func _ready() -> void:
    new_game_button.pressed.connect(_on_new_game_pressed)
    debug_scenarios_button.pressed.connect(_on_debug_scenarios_pressed)
    options_button.pressed.connect(_on_options_pressed)
    exit_button.pressed.connect(_on_exit_pressed)
    options_menu.visible = false
    main_control.visible = true


func _on_new_game_pressed() -> void:
    get_tree().change_scene_to_file("res://src/Scenes/menu/CharacterSelect.tscn")


## Opens the debug scenario picker, which jumps into a run that is already
## mid/endgame. The default way to play is still `_on_new_game_pressed()`.
func _on_debug_scenarios_pressed() -> void:
    if not ResourceLoader.exists(DEBUG_SCENARIOS_SCENE):
        push_warning("MainMenu: debug scenarios are not in this build (%s missing)" % DEBUG_SCENARIOS_SCENE)
        return
    get_tree().change_scene_to_file(DEBUG_SCENARIOS_SCENE)


func _on_options_pressed() -> void:
    main_control.visible = false
    options_menu.visible = true


func _on_exit_pressed() -> void:
    get_tree().quit()