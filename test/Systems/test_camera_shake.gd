class_name CameraShakeTest
extends GdUnitTestSuite

## The game camera shakes a little when its target attacks and harder when the
## target takes damage, scaled by `GameSettings.screen_shake` (0 = off). The
## pixel sizes are tuning exports, so the suite asserts the mechanic - which
## event shakes, which shakes harder, how the slider scales it - never a literal.

const CAMERA_SCRIPT := preload("res://src/Scripts/camera_2d.gd")

var _saved_shake := 0.0
var _target: Node2D
var _events: EventManager
var _camera: Camera2D


func before_test() -> void:
    _saved_shake = GameSettings.screen_shake
    GameSettings.screen_shake = 100.0
    _target = auto_free(Node2D.new())
    _events = EventManager.new()
    _events.name = "EventManager"
    _target.add_child(_events)
    add_child(_target)
    _camera = auto_free(CAMERA_SCRIPT.new())
    _camera.target = _target
    add_child(_camera)


func after_test() -> void:
    GameSettings.screen_shake = _saved_shake


func _attack() -> void:
    _events.emit_event("on_attack", {"weapon": null})


func _take_damage(amount: float) -> void:
    var ctx := DamageContext.new()
    ctx.final_amount = amount
    _events.emit_event("after_take_damage", {"damage_context": ctx})


func test_attack_shakes_the_camera() -> void:
    _attack()
    assert_float(_camera.shake_strength).is_equal_approx(_camera.attack_shake, 0.001)


func test_taking_damage_shakes_harder_than_attacking() -> void:
    _take_damage(5.0)
    assert_float(_camera.shake_strength).is_equal_approx(_camera.damage_shake, 0.001)
    assert_float(_camera.damage_shake).is_greater(_camera.attack_shake)


## A fully blocked hit is not a hit the player should feel.
func test_zero_damage_does_not_shake() -> void:
    _take_damage(0.0)
    assert_float(_camera.shake_strength).is_equal(0.0)


## An area weapon fires `on_attack` once per enemy in range, so many kicks in
## one frame must not add up to more than one attack's shake.
func test_repeated_attacks_do_not_stack() -> void:
    for i in 10:
        _attack()
    assert_float(_camera.shake_strength).is_equal_approx(_camera.attack_shake, 0.001)


func test_a_small_kick_does_not_cut_a_big_one_short() -> void:
    _take_damage(5.0)
    _attack()
    assert_float(_camera.shake_strength).is_equal_approx(_camera.damage_shake, 0.001)


func test_slider_scales_the_shake() -> void:
    GameSettings.screen_shake = 50.0
    _take_damage(5.0)
    assert_float(_camera.shake_strength).is_equal_approx(_camera.damage_shake * 0.5, 0.001)


func test_slider_at_zero_turns_shake_off() -> void:
    GameSettings.screen_shake = 0.0
    _attack()
    _take_damage(5.0)
    _camera._process(0.016)
    assert_float(_camera.shake_strength).is_equal(0.0)
    assert_vector(_camera.offset).is_equal(Vector2.ZERO)


func test_shake_fades_back_to_rest() -> void:
    _take_damage(5.0)
    _camera._process(0.016)
    assert_float(_camera.shake_strength).is_less(_camera.damage_shake)
    _camera._process(_camera.damage_shake / _camera.shake_decay + 0.1)
    assert_float(_camera.shake_strength).is_equal(0.0)
    assert_vector(_camera.offset).is_equal(Vector2.ZERO)
