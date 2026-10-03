# GdUnit TestSuite for SoundManager pitch handling and the MenuButton sound effects
class_name SoundManagerPitchTest
extends GdUnitTestSuite

const FOCUS_SOUND := "res://src/Assets/sounds/ui/button_focus.wav"
const PRESS_SOUND := "res://src/Assets/sounds/ui/button_press.wav"


# A pitch_rand of 1.0 or more previously produced a zero/negative pitch_scale,
# which made AudioStreamPlayer reject the sound outright.
func test_pitch_scale_never_reaches_zero_or_below() -> void:
    for pitch_rand in [0.0, 0.2, 1.0, 2.0, 5.0, 100.0]:
        for _i in 50:
            var pitch: float = SoundManager._pick_pitch(pitch_rand)
            assert_float(pitch).is_greater_equal(SoundManager.MIN_PITCH_SCALE)


func test_pick_pitch_is_centred_on_one() -> void:
    var samples: Array[float] = []
    for _i in 200:
        samples.append(SoundManager._pick_pitch(0.2))
    var total := 0.0
    for s in samples:
        total += s
    # Random offset around 1.0, well inside the +/- 0.2 range.
    assert_float(total / samples.size()).is_between(0.9, 1.1)


func test_pick_pitch_honours_range() -> void:
    for _i in 200:
        assert_float(SoundManager._pick_pitch(0.25)).is_between(0.75, 1.25)


func test_play_queues_and_playing_applies_valid_pitch() -> void:
    var souds_size: int = SoundManager.sounds_to_play.size()
    SoundManager.play(preload(FOCUS_SOUND), 0.0, 2.0)
    assert_int(SoundManager.sounds_to_play.size()).is_equal(souds_size + 1)
    SoundManager._playSound()
    assert_float(SoundManager.players_available[0].pitch_scale)\
        .is_greater_equal(SoundManager.MIN_PITCH_SCALE)


func test_play_never_queues_more_than_max_sounds() -> void:
    SoundManager.sounds_to_play.clear()
    for _i in SoundManager.MAX_SOUNDS + 5:
        SoundManager.play(preload(FOCUS_SOUND), 0.0, 0.2)
    assert_int(SoundManager.sounds_to_play.size()).is_equal(SoundManager.MAX_SOUNDS)
    SoundManager.sounds_to_play.clear()


# --- MenuButton ---

func _make_button() -> UiMenuButton:
    var button := UiMenuButton.new()
    add_child(button)
    return button


func test_menu_button_plays_focus_sound_on_hover() -> void:
    var button := _make_button()
    var souds_size: int = SoundManager.sounds_to_play.size()
    button.on_mouse_entered()
    # Exactly one sound: grab_focus() also emits focus_entered, which must not
    # stack a second copy of the focus sound on top of the hover sound.
    assert_int(SoundManager.sounds_to_play.size()).is_equal(souds_size + 1)


func test_menu_button_hover_always_sounds_once() -> void:
    var button := _make_button()
    for _i in 10:
        var souds_size: int = SoundManager.sounds_to_play.size()
        button.on_mouse_entered()
        assert_int(SoundManager.sounds_to_play.size()).is_equal(souds_size + 1)


func test_menu_button_plays_press_sound_and_locks_repress() -> void:
    var button := _make_button()
    var souds_size: int = SoundManager.sounds_to_play.size()
    button.on_pressed()
    assert_int(SoundManager.sounds_to_play.size()).is_equal(souds_size + 1)
    # Button is disabled right after pressing to swallow double clicks.
    assert_bool(button.disabled).is_true()


func test_menu_button_grabs_focus_on_hover() -> void:
    var button := _make_button()
    button.on_mouse_entered()
    assert_int(button.focus_mode).is_equal(Control.FOCUS_ALL)
    assert_object(button.get_viewport().gui_get_focus_owner()).is_same(button)


func test_menu_button_does_not_grab_focus_when_disabled_opt_out() -> void:
    var button := _make_button()
    button.grab_focus_with_mouse = false
    var souds_size: int = SoundManager.sounds_to_play.size()
    button.on_mouse_entered()
    # Sound still plays, focus is left alone.
    assert_int(SoundManager.sounds_to_play.size()).is_equal(souds_size + 1)
    assert_object(button.get_viewport().gui_get_focus_owner()).is_not_same(button)


func test_menu_button_disable_activates_round_trip() -> void:
    var button := _make_button()
    button.disable()
    var souds_size: int = SoundManager.sounds_to_play.size()
    button.on_mouse_entered()
    button.on_pressed()
    # Muted button queues nothing.
    assert_int(SoundManager.sounds_to_play.size()).is_equal(souds_size)
    button.activate()
    button.on_mouse_entered()
    assert_int(SoundManager.sounds_to_play.size()).is_equal(souds_size + 1)


func test_menu_button_sounds_exist_and_are_distinct() -> void:
    var focus: Resource = load(FOCUS_SOUND)
    var press: Resource = load(PRESS_SOUND)
    assert_object(focus).is_not_null()
    assert_object(press).is_not_null()
    assert_bool(focus == press).is_false()
