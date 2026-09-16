# GdUnit generated TestSuite
class_name PauseMenuGdUnit4Test
extends GdUnitTestSuite

const PAUSE_MENU_SCENE_PATH := "res://src/Scenes/menu/PauseMenu.tscn"

var pause_menu: CanvasLayer


func before_test() -> void:
    pause_menu = load(PAUSE_MENU_SCENE_PATH).instantiate()
    add_child(pause_menu)


func after_test() -> void:
    if is_instance_valid(pause_menu):
        pause_menu.queue_free()
        pause_menu = null
    collect_orphan_node_details()


func test_pause_menu_has_main_menu_button() -> void:
    var main_menu_button: Button = pause_menu.get_node("Control/VBoxContainer/MainMenuButton")
    assert_object(main_menu_button).is_not_null()
    assert_str(main_menu_button.text).is_equal("Main menu")


func test_main_menu_button_opens_main_scene() -> void:
    assert_str(pause_menu.MAIN_MENU_SCENE_PATH).is_equal("res://src/Scenes/menu/Main.tscn")
    assert_bool(FileAccess.file_exists(pause_menu.MAIN_MENU_SCENE_PATH)).is_true()
    assert_bool(ResourceLoader.exists(pause_menu.MAIN_MENU_SCENE_PATH)).is_true()
    var main_menu_button: Button = pause_menu.get_node("Control/VBoxContainer/MainMenuButton")
    assert_bool(main_menu_button.pressed.is_connected(Callable(pause_menu, "_on_main_menu_pressed"))).is_true()
