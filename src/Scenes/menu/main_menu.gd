extends CanvasLayer

## Main menu: the parallax background stack plus the button navigation.
##
## The three `MenuParallaxLayer` nodes are siblings of `Control` rather than
## children of it, so hiding `Control` for the options menu leaves the
## background moving behind it.
##
## The menu also changes scene and drives the background sway, which is two jobs
## in one script. It is still short enough to be worth keeping together; if it
## grows much further, split the driver out.

const LAYER_NAMES := ["FarLayer", "MidLayer", "NearLayer"]

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

var _layers: Array[MenuParallaxLayer] = []
var _sway_time: float = 0.0
var _mouse_shift: float = 0.0
var _mouse_target: float = 0.0


func _ready() -> void:
    new_game_button.pressed.connect(_on_new_game_pressed)
    debug_scenarios_button.pressed.connect(_on_debug_scenarios_pressed)
    options_button.pressed.connect(_on_options_pressed)
    exit_button.pressed.connect(_on_exit_pressed)
    options_menu.visible = false
    main_control.visible = true

    for layer_name in LAYER_NAMES:
        _layers.append(get_node(layer_name) as MenuParallaxLayer)


func _process(delta: float) -> void:
    _sway_time += delta
    _mouse_target = _mouse_deflection()
    # Frame-rate independent ease toward the mouse, so the layers lean after the
    # cursor instead of snapping to it. Exponential rather than a fixed step,
    # which would move at a different speed on a different frame rate.
    _mouse_shift = lerpf(_mouse_shift, _mouse_target, 1.0 - exp(-delta / _follow_time()))
    for parallax_layer in _layers:
        # Additive, and each layer's own travel budget clamps the sum, so the
        # mouse can never push a layer further than the cover-fit has slack for.
        parallax_layer.set_shift(
            parallax_layer.sway_at(_sway_time) + _mouse_shift * parallax_layer.mouse_travel)


## Mouse position as -1.0 at the left edge to 1.0 at the right.
func _mouse_deflection() -> float:
    var visible_rect := get_viewport().get_visible_rect()
    var half_width := visible_rect.size.x * 0.5
    if half_width <= 0.0:
        return 0.0
    var from_centre := (
        get_viewport().get_mouse_position().x - visible_rect.position.x - half_width
    )
    return clampf(from_centre / half_width, -1.0, 1.0)


func _follow_time() -> float:
    # Every layer shares one follow time; the first is the reference.
    return _layers[0].mouse_follow if not _layers.is_empty() else 0.35


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
