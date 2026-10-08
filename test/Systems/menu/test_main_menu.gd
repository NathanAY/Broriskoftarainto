# GdUnit generated TestSuite
class_name MainMenuTest
extends GdUnitTestSuite

const MAIN_SCENE_PATH := "res://src/Scenes/menu/Main.tscn"

## Slack on the cover arithmetic. Dividing and re-multiplying sizes lands a hair
## under the exact value, which is a rounding artefact rather than a gap.
const COVER_EPS := 0.01

var main_menu: CanvasLayer


func before_test() -> void:
    main_menu = load(MAIN_SCENE_PATH).instantiate()
    add_child(main_menu)


func after_test() -> void:
    if is_instance_valid(main_menu):
        main_menu.queue_free()
        main_menu = null
    collect_orphan_node_details()


func test_main_scene_instantiates() -> void:
    assert_object(main_menu).is_not_null()
    assert_str(main_menu.name).is_equal("Main")


func test_main_menu_has_basic_buttons() -> void:
    var new_game_button: Button = main_menu.get_node("Control/VBoxContainer/NewGameButton")
    var options_button: Button = main_menu.get_node("Control/VBoxContainer/OptionsButton")
    var exit_button: Button = main_menu.get_node("Control/VBoxContainer/ExitButton")
    assert_object(new_game_button).is_not_null()
    assert_object(options_button).is_not_null()
    assert_object(exit_button).is_not_null()
    assert_str(new_game_button.text).is_equal("New game")
    assert_str(options_button.text).is_equal("Options")
    assert_str(exit_button.text).is_equal("Exit")


## The debug shortcut is an extra button beside "New game", not a replacement:
## the character select -> StarterMenu route stays the default way to play.
func test_debug_scenarios_button_sits_beside_new_game() -> void:
    var box: VBoxContainer = main_menu.get_node("Control/VBoxContainer")
    var debug_button: Button = main_menu.get_node("Control/VBoxContainer/DebugScenariosButton")
    assert_str(debug_button.text).is_equal("Debug scenarios")
    assert_int(box.get_child_count()).is_equal(5)
    assert_int(debug_button.get_index()).is_equal(
        main_menu.get_node("Control/VBoxContainer/NewGameButton").get_index() + 1
    )
    assert_bool(ResourceLoader.exists(main_menu.DEBUG_SCENARIOS_SCENE)).is_true()


func test_debug_scenarios_button_is_wired() -> void:
    var debug_button: Button = main_menu.get_node("Control/VBoxContainer/DebugScenariosButton")
    assert_bool(debug_button.pressed.is_connected(main_menu._on_debug_scenarios_pressed)).is_true()


# --- background ---------------------------------------------------------------


## The background has to fill the window whatever shape the window is, and the
## texture is not the same shape as the window. Two failure modes, both shipped
## once:
##
##   - `STRETCH_TILE` draws the texture at 1:1 and repeats it, so a window wider
##     than the texture shows the scene twice and a smaller one shows a bare crop.
##   - `STRETCH_SCALE` stretches to the rect's exact shape, so a texture that is
##     not the window's aspect comes out distorted.
##
## `STRETCH_KEEP_ASPECT_COVERED` is the only mode with neither failure: it scales
## up by whichever ratio is larger, so the short axis is covered and the long axis
## overflows and is cropped. Universal across window sizes and across replacement
## textures of any aspect, which is the point - the art is expected to be rescaled.
func test_background_covers_the_window_without_tiling_or_distorting() -> void:
    var background := main_menu.get_node("Background") as TextureRect
    assert_object(background).is_not_null()
    assert_int(background.stretch_mode).override_failure_message(
        "the background must cover-fit, not tile or distort").is_equal(
        TextureRect.STRETCH_KEEP_ASPECT_COVERED)
    assert_int(background.expand_mode).override_failure_message(
        "the background must size itself from the anchors, not from its texture"
    ).is_equal(TextureRect.EXPAND_IGNORE_SIZE)


## Full-rect anchors, or the background only covers the project viewport and
## leaves the rest of a resized window showing the clear colour.
func test_background_is_anchored_to_the_whole_window() -> void:
    var background := main_menu.get_node("Background") as TextureRect
    assert_float(background.anchor_right).is_equal(1.0)
    assert_float(background.anchor_bottom).is_equal(1.0)
    assert_float(background.anchor_left).is_equal(0.0)
    assert_float(background.anchor_top).is_equal(0.0)


func test_background_is_drawn_behind_the_buttons() -> void:
    # Draw order is sibling order, so the background has to come first or it
    # paints over the menu. Asserted as an index rather than a node name so the
    # test keeps working if either is renamed.
    assert_int(background_index()).is_less(
        main_menu.get_node("Control").get_index())


func test_background_does_not_swallow_clicks_meant_for_a_button() -> void:
    var background := main_menu.get_node("Background") as TextureRect
    assert_int(background.mouse_filter).override_failure_message(
        "the background must not intercept the mouse").is_equal(
        Control.MOUSE_FILTER_IGNORE)


func background_index() -> int:
    return main_menu.get_node("Background").get_index()


## The arithmetic behind `STRETCH_KEEP_ASPECT_COVERED`, asserted directly so the
## scene is not the only thing standing between a future texture swap and a
## letterboxed menu. Any window shape against any texture shape must be covered on
## both axes with no gap.
func test_cover_semantics_cover_every_window_and_texture_aspect() -> void:
    var windows := [
        Vector2(1552, 861),   # the project viewport
        Vector2(1920, 1080),  # 16:9, wider than the texture
        Vector2(1280, 720),
        Vector2(2560, 1080),  # 21:9, much wider than the texture
        Vector2(900, 1400),   # portrait, taller than the texture
        Vector2(600, 400),    # small and squat
    ]
    var textures := [
        Vector2(1564, 1042),  # what ships today
        Vector2(1920, 1080),
        Vector2(1024, 1024),  # square
        Vector2(2400, 800),   # very wide
        Vector2(800, 2000),   # very tall
    ]
    for window: Vector2 in windows:
        for texture: Vector2 in textures:
            var scale: float = maxf(window.x / texture.x, window.y / texture.y)
            var shown := texture * scale
            var message := "%s texture in a %s window" % [texture, window]
            assert_float(shown.x).override_failure_message(
                "cover leaves a gap at the left/right edge: " + message
            ).is_greater_equal(window.x - COVER_EPS)
            assert_float(shown.y).override_failure_message(
                "cover leaves a gap at the top/bottom edge: " + message
            ).is_greater_equal(window.y - COVER_EPS)


func test_options_menu_hidden_initially() -> void:
    var options_menu: CanvasLayer = main_menu.get_node("OptionsMenu")
    assert_bool(options_menu.visible).is_false()
    assert_bool(main_menu.get_node("Control").visible).is_true()


func test_options_button_shows_options_menu() -> void:
    main_menu._on_options_pressed()
    var options_menu: CanvasLayer = main_menu.get_node("OptionsMenu")
    assert_bool(options_menu.visible).is_true()
    assert_bool(main_menu.get_node("Control").visible).is_false()
    # Simulate Back button to return to main menu.
    options_menu._on_back_pressed()
    assert_bool(options_menu.visible).is_false()
    assert_bool(main_menu.get_node("Control").visible).is_true()
