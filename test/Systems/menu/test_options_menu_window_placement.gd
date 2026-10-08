# GdUnit generated TestSuite
class_name GameSettingsWindowPlacementTest
extends GdUnitTestSuite

const WINDOW_SIZE := Vector2i(1280, 720)

## Scratch file so a test run never reads or writes the player's real
## `user://settings.cfg`, and never leaves a mode behind that the next test
## would inherit.
const SCRATCH_PATH := "user://test_game_settings_window_placement.cfg"

## The window geometry this suite asserts used to live on `OptionsMenu`. It is
## on `GameSettings` now because that is where the choice survives a scene
## change - see `src/Scripts/autoload/game_settings.gd`. Preloaded rather than
## reached through the autoload, because `centered_in_screen_rect()` is static
## and calling a static function off an instance warns at every call site.
const SETTINGS_SCRIPT := preload("res://src/Scripts/autoload/game_settings.gd")

var _saved_settings_path := ""


func before_test() -> void:
    _saved_settings_path = GameSettings.settings_path
    GameSettings.settings_path = SCRATCH_PATH
    GameSettings.reset_to_defaults()


func after_test() -> void:
    GameSettings.settings_path = _saved_settings_path
    if FileAccess.file_exists(SCRATCH_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_PATH))
    collect_orphan_node_details()


## A secondary monitor at x=2560 must not be treated as sitting at 0,0: the
## screen's position offset has to end up in the centered window position.
func test_centering_accounts_for_screen_offset() -> void:
    var screen_rect := Rect2i(2560, 0, 1920, 1080)
    var expected := Vector2i(2880, 180)

    var centered: Vector2i = SETTINGS_SCRIPT.centered_in_screen_rect(WINDOW_SIZE, screen_rect)

    assert_that(centered).is_equal(expected)


func test_centering_on_primary_screen_ignores_no_offset() -> void:
    var screen_rect := Rect2i(0, 0, 1920, 1080)

    var centered: Vector2i = SETTINGS_SCRIPT.centered_in_screen_rect(WINDOW_SIZE, screen_rect)

    assert_that(centered).is_equal(Vector2i(320, 180))


func test_centering_handles_a_window_larger_than_its_screen() -> void:
    # Over-sized windows get a negative offset, which is what Godot expects
    # rather than clamping the window to the screen edge.
    var screen_rect := Rect2i(100, 50, 800, 600)

    var centered: Vector2i = SETTINGS_SCRIPT.centered_in_screen_rect(WINDOW_SIZE, screen_rect)

    assert_that(centered).is_equal(Vector2i(-140, -10))


## apply_window_mode must leave the window centered on the screen it is on,
## which is what keeps it from jumping to the primary monitor on scene changes.
func test_apply_window_mode_centers_on_the_current_screen() -> void:
    GameSettings.apply_window_mode()

    var screen_id := DisplayServer.window_get_current_screen()
    var screen_rect := Rect2i(
        DisplayServer.screen_get_position(screen_id), DisplayServer.screen_get_size(screen_id)
    )
    assert_that(DisplayServer.window_get_position()).is_equal(
        SETTINGS_SCRIPT.centered_in_screen_rect(WINDOW_SIZE, screen_rect)
    )
