class_name LowHealthVignetteTest
extends GdUnitTestSuite

## The screen-edge shadow is invisible at full health and deepens as health
## falls, reaching `max_alpha` at zero. `max_alpha` is a tuning export, so the
## expectations are derived from it rather than pinned.

const VIGNETTE_SCRIPT := preload("res://src/ui/low_health_vignette.gd")


func _make_vignette() -> LowHealthVignette:
    var vignette: LowHealthVignette = auto_free(VIGNETTE_SCRIPT.new())
    add_child(vignette)
    return vignette


func test_invisible_at_full_health() -> void:
    var vignette := _make_vignette()
    vignette.set_health(50.0, 50.0)
    assert_float(vignette.modulate.a).is_equal(0.0)


func test_strongest_at_zero_health() -> void:
    var vignette := _make_vignette()
    vignette.set_health(0.0, 50.0)
    assert_float(vignette.modulate.a).is_equal_approx(vignette.max_alpha, 0.001)


func test_lower_health_means_a_stronger_shadow() -> void:
    var vignette := _make_vignette()
    vignette.set_health(40.0, 50.0)
    var high_hp_alpha := vignette.modulate.a
    vignette.set_health(10.0, 50.0)
    assert_float(vignette.modulate.a).is_greater(high_hp_alpha)
    assert_float(high_hp_alpha).is_greater(0.0)


## Relative to the maximum: the same missing fraction gives the same shadow.
func test_strength_follows_the_health_fraction() -> void:
    var vignette := _make_vignette()
    vignette.set_health(25.0, 100.0)
    var quarter_alpha := vignette.modulate.a
    vignette.set_health(5.0, 20.0)
    assert_float(vignette.modulate.a).is_equal_approx(quarter_alpha, 0.001)
    assert_float(quarter_alpha).is_equal_approx(0.75 * vignette.max_alpha, 0.001)


## Overheal or overkill readings must not push the alpha out of range.
func test_out_of_range_health_is_clamped() -> void:
    var vignette := _make_vignette()
    vignette.set_health(-10.0, 50.0)
    assert_float(vignette.modulate.a).is_equal_approx(vignette.max_alpha, 0.001)
    vignette.set_health(80.0, 50.0)
    assert_float(vignette.modulate.a).is_equal(0.0)
    vignette.set_health(10.0, 0.0)
    assert_float(vignette.modulate.a).is_equal(0.0)


## The character's own health event drives it in game.
func test_follows_the_on_health_changed_event() -> void:
    var vignette := _make_vignette()
    vignette._on_health_changed({"self": null, "amount": -30.0, "current_health": 20.0, "max_health": 50.0})
    assert_float(vignette.modulate.a).is_equal_approx(0.6 * vignette.max_alpha, 0.001)


## An overlay that ate clicks would block the HUD and menus under it.
func test_covers_the_screen_and_ignores_the_mouse() -> void:
    var vignette := _make_vignette()
    assert_int(vignette.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
    assert_float(vignette.anchor_right).is_equal(1.0)
    assert_float(vignette.anchor_bottom).is_equal(1.0)
    # Anchors alone left the rect at size 0, which drew nothing at all.
    assert_vector(vignette.size).is_equal(vignette.get_viewport_rect().size)


## The edge is dark and the centre clear, so the player's view is not dimmed.
func test_shadow_is_clear_in_the_centre_and_dark_at_the_edge() -> void:
    var vignette := _make_vignette()
    var gradient: Gradient = (vignette.texture as GradientTexture2D).gradient
    assert_float(gradient.sample(0.0).a).is_equal(0.0)
    assert_float(gradient.sample(1.0).a).is_equal(1.0)
