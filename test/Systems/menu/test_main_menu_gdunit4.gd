# GdUnit generated TestSuite
class_name MainMenuGdUnit4Test
extends GdUnitTestSuite

const MAIN_SCENE_PATH := "res://src/Scenes/menu/Main.tscn"

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
