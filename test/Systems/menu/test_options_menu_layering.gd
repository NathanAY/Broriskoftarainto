# GdUnit generated TestSuite
class_name OptionsMenuLayeringTest
extends GdUnitTestSuite

## `OptionsMenu` is a `CanvasLayer` nested inside its host's `CanvasLayer`
## (`Main.tscn`, `PauseMenu.tscn`). Two canvases that share a layer index have a
## non-deterministic draw order, and the loser is whichever one the renderer
## happens to sort first - which here was the options menu, so pressing
## "Options" hid the main menu and left a bare background on screen. The
## buttons still took clicks, because GUI input is not ordered by canvas the
## same way drawing is, which made it look like a dead click rather than a
## layering bug.
##
## The fix is to give the overlay a layer strictly above the host's, so no
## renderer's sort order can put it behind the menu background. These tests pin
## that for every scene that instances the options menu, because the bug only
## shows up in the running window - a scene-level `visible` assertion passes
## while nothing is drawn.

const OPTIONS_MENU_SCENE_PATH := "res://src/Scenes/menu/OptionsMenu.tscn"

## Every scene that instances OptionsMenu.tscn, with the path to the instance.
## The dict is the whole list: adding a third host scene means adding it here,
## or it goes unchecked.
const HOST_SCENES := {
    "res://src/Scenes/menu/Main.tscn": "OptionsMenu",
    "res://src/Scenes/menu/PauseMenu.tscn": "OptionsMenu",
}


func test_options_menu_layer_is_above_every_host() -> void:
    var options_layer := load(OPTIONS_MENU_SCENE_PATH).instantiate() as CanvasLayer
    assert_int(options_layer.layer).override_failure_message(
        "the options overlay must sit on its own layer above the menu background").is_greater(1)
    options_layer.free()


## A nested CanvasLayer at the same index as its parent is the actual bug, so
## each host is checked rather than the shared constant above: a host may move
## to a higher layer later and take the options menu with it.
func test_no_host_shares_the_options_menu_layer() -> void:
    for scene_path: String in HOST_SCENES:
        var host := load(scene_path).instantiate() as CanvasLayer
        var options := host.get_node(HOST_SCENES[scene_path]) as CanvasLayer
        assert_int(options.layer).override_failure_message(
            "%s hosts the options menu on layer %d, the same index as its host: "
            % [scene_path, host.layer]
            + "draw order between the two canvases is undefined"
        ).is_greater(host.layer)
        host.free()