extends CanvasLayer

## The options panel: window mode, show-stats and the three volume sliders.
##
## Every value lives in the `GameSettings` autoload, not on this node. This menu
## is instanced once per menu scene, so state kept here was thrown away by the
## next scene change - which is what made the window size and the volumes snap
## back to their defaults on the way to the main menu and on the way into a run.

@onready var window_button: Button = $Control/VBoxContainer/WindowButton
@onready var show_stats_button: CheckButton = $Control/VBoxContainer/ShowStats
@onready var sound_slider: HSlider = $Control/VBoxContainer/SoundSlider
@onready var music_slider: HSlider = $Control/VBoxContainer/MusicSlider
@onready var sfx_slider: HSlider = $Control/VBoxContainer/SfxSlider
@onready var back_button: Button = $Control/VBoxContainer/BackButton


func _ready() -> void:
    # Controls first, then the stored values. Assigning a slider value emits
    # `value_changed` and a CheckButton's `button_pressed` does not, so filling
    # the controls in before anything is wired means the values below are read
    # from GameSettings instead of written straight back over them.
    _read_settings_into_controls()

    window_button.pressed.connect(_on_window_toggle_pressed)
    show_stats_button.pressed.connect(_on_show_stats_toggled)
    back_button.pressed.connect(_on_back_pressed)

    sound_slider.value_changed.connect(_on_sound_volume_changed)
    music_slider.value_changed.connect(_on_music_volume_changed)
    sfx_slider.value_changed.connect(_on_sfx_volume_changed)

    # Re-assert rather than trust: a scene change can rebuild the window
    # between two visits to this menu, and this is where it gets put back.
    GameSettings.apply_window_mode()
    GameSettings.apply_volumes()
    _apply_show_stats()


## Mirrors the stored options onto the controls.
func _read_settings_into_controls() -> void:
    window_button.text = GameSettings.window_mode_label()
    show_stats_button.button_pressed = GameSettings.show_stats
    sound_slider.value = GameSettings.sound_volume
    music_slider.value = GameSettings.music_volume
    sfx_slider.value = GameSettings.sfx_volume


func _on_window_toggle_pressed() -> void:
    GameSettings.cycle_window_mode()
    window_button.text = GameSettings.window_mode_label()


func _on_show_stats_toggled() -> void:
    GameSettings.set_show_stats(show_stats_button.button_pressed)
    _apply_show_stats()


## Shows or hides the stats panel this menu belongs to. A menu that has no
## stats panel under it (the main menu) has nothing to toggle.
func _apply_show_stats() -> void:
    var ui_root: Node = get_parent().get_parent()
    if ui_root == null or not ui_root.has_node("CanvasLayer/CharacterUi/PanelContainer"):
        return
    var charactUI: Control = ui_root.get_node("CanvasLayer/CharacterUi/PanelContainer")
    charactUI.visible = GameSettings.show_stats


# ------------------ AUDIO ------------------
func _on_sound_volume_changed(value: float) -> void:
    GameSettings.set_sound_volume(value)


func _on_music_volume_changed(value: float) -> void:
    GameSettings.set_music_volume(value)


func _on_sfx_volume_changed(value: float) -> void:
    GameSettings.set_sfx_volume(value)


func _on_back_pressed() -> void:
    visible = false
    get_parent().get_node("Control").visible = true