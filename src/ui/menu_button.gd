class_name UiMenuButton
extends Button
## Button with menu sound effects: focus sound on mouse_enter / focus_enter,
## press sound on click, plus a short re-press lockout and grab-focus-on-hover.

const DEFAULT_FOCUS_SOUND := preload("res://src/Assets/sounds/ui/button_focus.wav")
const DEFAULT_PRESS_SOUND := preload("res://src/Assets/sounds/ui/button_press.wav")

## Seconds the button stays disabled after being pressed (prevents double clicks).
@export var press_lockout_time: float = 0.05

## Random pitch offset applied when playing the sounds.
@export_range(0.0, 1.0, 0.01) var pitch_variation: float = 0.2

@export var focus_entered_sound: Resource = DEFAULT_FOCUS_SOUND
@export var pressed_sound: Resource = DEFAULT_PRESS_SOUND

@export var grab_focus_with_mouse: bool = true

## When false the button is muted and ignores hover focus grabbing.
var active: bool = true

var _delay_timer: Timer
var _is_delay_active: bool = false


func _ready() -> void:
	_delay_timer = Timer.new()
	_delay_timer.wait_time = press_lockout_time
	_delay_timer.one_shot = true
	_delay_timer.timeout.connect(_on_delay_timer_timeout)
	add_child(_delay_timer)

	focus_entered.connect(on_focus_entered)
	pressed.connect(on_pressed)
	mouse_entered.connect(on_mouse_entered)


func on_focus_entered() -> void:
	if active and focus_entered_sound:
		SoundManager.play(focus_entered_sound, 0, pitch_variation)


func on_pressed() -> void:
	if not active:
		return
	if is_inside_tree():
		_delay_timer.start()
		disabled = true
		_is_delay_active = true
	if pressed_sound:
		SoundManager.play(pressed_sound, 0, pitch_variation)


func on_mouse_entered() -> void:
	if not active:
		return
	var played_by_focus_grab := false
	if grab_focus_with_mouse:
		if focus_mode == Control.FOCUS_NONE:
			focus_mode = Control.FOCUS_ALL
		var was_focused := has_focus()
		grab_focus()
		# grab_focus() emits focus_entered synchronously, and on_focus_entered()
		# already plays the sound. Without this guard every hover would play it
		# twice, once per signal.
		played_by_focus_grab = not was_focused and has_focus()
	if not played_by_focus_grab and focus_entered_sound:
		SoundManager.play(focus_entered_sound, 0, pitch_variation)


## Permanently mutes and disables the button until `activate()` is called.
func disable() -> void:
	disabled = true
	focus_mode = Control.FOCUS_NONE
	active = false
	_is_delay_active = false


## Re-enables a button previously turned off with `disable()`.
func activate() -> void:
	disabled = false
	focus_mode = Control.FOCUS_ALL
	active = true


func _on_delay_timer_timeout() -> void:
	if _is_delay_active:
		disabled = false
		_is_delay_active = false
