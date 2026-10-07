# GdUnit generated TestSuite
class_name WindowFocusTest
extends GdUnitTestSuite

## The real autoload, not a fresh instance: the startup raise it performs has
## already run by the time a test body starts, and a freshly added node would
## have its own _ready -> _raise_once() racing the assertions.
var window_focus: Node
var runner


func before_test() -> void:
    window_focus = (Engine.get_main_loop() as SceneTree).root.get_node("WindowFocus")
    runner = scene_runner("res://test/TestScene.tscn")
    runner.scene()


func _is_on_top() -> bool:
    return DisplayServer.window_get_flag(
        DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, DisplayServer.MAIN_WINDOW_ID
    )


## The raise is an autoload rather than a call inside a scene, because the
## window has to come forward before the main scene is on screen.
func test_registered_as_an_autoload() -> void:
    var registered: Variant = ProjectSettings.get_setting("autoload/WindowFocus", null)
    assert_that(registered).is_equal("*res://src/Scripts/autoload/window_focus.gd")
    assert_object(window_focus).is_not_null()


## The window has to be in front *during* the hold...
func test_raise_over_holds_the_window_above_other_windows() -> void:
    window_focus.raise_over(3)
    await runner.simulate_frames(1)
    assert_bool(_is_on_top()).is_true()

    # ...and released once the hold is over. This is the whole difference
    # between "opens on top" and "always on top": leaving the flag set would
    # pin the game above every other app for the whole session.
    await runner.simulate_frames(10)
    assert_bool(_is_on_top()).is_false()


## The startup sequence runs to completion long before any test body, so its end
## state is the only part observable from outside. It must not leave the window
## pinned, otherwise the game floats above every other app.
func test_startup_does_not_leave_the_window_pinned_on_top() -> void:
    await runner.simulate_frames(30)
    assert_bool(_is_on_top()).is_false()


func test_set_window_raised_toggles_the_topmost_flag() -> void:
    window_focus.set_window_raised(true)
    assert_bool(_is_on_top()).is_true()

    window_focus.set_window_raised(false)
    assert_bool(_is_on_top()).is_false()


## set_window_raised() must not blow up when there is no real window to raise,
## so the headless test runner and a headless export can both call it.
func test_set_window_raised_is_safe_headless() -> void:
    window_focus.set_window_raised(true)
    window_focus.set_window_raised(false)
    assert_bool(_is_on_top()).is_false()


## Raising is only a z-order operation. A focus attempt must not also nudge the
## window the way the old options-menu centring did.
func test_raising_does_not_move_or_resize_the_window() -> void:
    var position_before: Vector2i = DisplayServer.window_get_position()
    var size_before: Vector2i = DisplayServer.window_get_size()

    window_focus.set_window_raised(true)

    assert_that(DisplayServer.window_get_position()).is_equal(position_before)
    assert_that(DisplayServer.window_get_size()).is_equal(size_before)