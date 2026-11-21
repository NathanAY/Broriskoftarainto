# GdUnit generated TestSuite
class_name OptionsMenuSliderLabelsTest
extends GdUnitTestSuite

## Each volume slider in the options panel needs a label directly above it, so
## the player can tell which bus it drives. The suite checks the structure
## (a Label sits immediately before each slider in the VBox, with text), not the
## wording or the layout pixels.

const OPTIONS_MENU_SCENE_PATH := "res://src/Scenes/menu/OptionsMenu.tscn"

const SLIDER_PATHS := [
    "Control/VBoxContainer/SoundSlider",
    "Control/VBoxContainer/MusicSlider",
    "Control/VBoxContainer/SfxSlider",
]


func _build_options_menu() -> CanvasLayer:
    var menu: CanvasLayer = load(OPTIONS_MENU_SCENE_PATH).instantiate()
    add_child(menu)
    return menu


func test_every_slider_has_a_label_right_above_it() -> void:
    var menu := _build_options_menu()
    var box: VBoxContainer = menu.get_node("Control/VBoxContainer")
    for slider_path in SLIDER_PATHS:
        var slider: HSlider = menu.get_node(slider_path)
        var index := slider.get_index()
        assert_bool(index > 0).is_true()
        var above := box.get_child(index - 1)
        assert_bool(above is Label).is_true()
        assert_str((above as Label).text).is_not_empty()
    menu.queue_free()


func test_slider_labels_are_distinct() -> void:
    var menu := _build_options_menu()
    var texts := {}
    for slider_path in SLIDER_PATHS:
        var slider: HSlider = menu.get_node(slider_path)
        var label := slider.get_parent().get_child(slider.get_index() - 1) as Label
        texts[label.text] = true
    assert_int(texts.size()).is_equal(SLIDER_PATHS.size())
    menu.queue_free()
