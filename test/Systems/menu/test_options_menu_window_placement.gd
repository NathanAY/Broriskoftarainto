# GdUnit generated TestSuite
class_name OptionsMenuWindowPlacementTest
extends GdUnitTestSuite

const OPTIONS_MENU_SCENE_PATH := "res://src/Scenes/menu/OptionsMenu.tscn"
const WINDOW_SIZE := Vector2i(1280, 720)

var options_menu: CanvasLayer


func before_test() -> void:
    options_menu = load(OPTIONS_MENU_SCENE_PATH).instantiate()
    add_child(options_menu)


func after_test() -> void:
    if is_instance_valid(options_menu):
        options_menu.queue_free()
        options_menu = null
    collect_orphan_node_details()


## A secondary monitor at x=2560 must not be treated as sitting at 0,0: the
## screen's position offset has to end up in the centered window position.
func test_centering_accounts_for_screen_offset() -> void:
    var screen_rect := Rect2i(2560, 0, 1920, 1080)
    var expected := Vector2i(2880, 180)

    var centered: Vector2i = options_menu.centered_in_screen_rect.call(WINDOW_SIZE, screen_rect)

    assert_that(centered).is_equal(expected)


func test_centering_on_primary_screen_ignores_no_offset() -> void:
    var screen_rect := Rect2i(0, 0, 1920, 1080)

    var centered: Vector2i = options_menu.centered_in_screen_rect.call(WINDOW_SIZE, screen_rect)

    assert_that(centered).is_equal(Vector2i(320, 180))


func test_centering_handles_a_window_larger_than_its_screen() -> void:
    # Over-sized windows get a negative offset, which is what Godot expects
    # rather than clamping the window to the screen edge.
    var screen_rect := Rect2i(100, 50, 800, 600)

    var centered: Vector2i = options_menu.centered_in_screen_rect.call(WINDOW_SIZE, screen_rect)

    assert_that(centered).is_equal(Vector2i(-140, -10))


## _apply_window_mode must leave the window centered on the screen it is on,
## which is what keeps it from jumping to the primary monitor on scene changes.
func test_apply_window_mode_centers_on_the_current_screen() -> void:
    options_menu._apply_window_mode()

    var screen_id := DisplayServer.window_get_current_screen()
    var screen_rect := Rect2i(
        DisplayServer.screen_get_position(screen_id),
        DisplayServer.screen_get_size(screen_id)
    )
    assert_that(DisplayServer.window_get_position()).is_equal(
        options_menu.centered_in_screen_rect.call(WINDOW_SIZE, screen_rect)
    )
