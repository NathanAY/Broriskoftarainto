# GdUnit TestSuite for the main menu's parallax background stack.
#
# What is being defended here, and why it is arithmetic rather than pixels:
#
# The background has to (a) cover whatever window it is in, and (b) slide
# sideways. Each of those is easy and the combination is not. A layer scaled to
# cover a window is exactly the window wide, so the first pixel it slides
# uncovers a gap down one side. The fix is to fit the art to the window *plus*
# the layer's whole horizontal travel*, and that is the invariant most of these
# tests rest on.
#
# These tests cannot see a seam, a colour that clashes, or a layer that moves at
# the wrong speed. Those still need the scene render. What they can do is pin
# down the geometry and the motion maths, which is where a regression would
# otherwise show up as a one-pixel sliver nobody notices until it ships.
class_name MenuParallaxTest
extends GdUnitTestSuite

const MAIN_SCENE_PATH := "res://src/Scenes/menu/Main.tscn"

## The project viewport, from project.godot. The overscan rule is stated against
## this width, so it is worth asserting rather than trusting.
const VIEWPORT := Vector2(1552, 861)

## Layer name -> [sway travel, sway period, sway phase, mouse travel].
## Mirrors docs/archive/main_menu_parallax_background.md. The scene is checked
## against this below, so retuning the motion means editing both, on purpose.
const EXPECTED_LAYERS := {
	"FarLayer": [24.0, 14.0, 0.0, 8.0],
	"MidLayer": [48.0, 10.0, 0.35, 14.0],
	"NearLayer": [84.0, 7.0, 0.7, 22.0],
}

## Window sizes to fit against. Deliberately includes one far taller than 16:9,
## because that is where a cover-fit that only ever scaled by width falls over.
const FIT_SIZES := [
	Vector2(1552, 861),
	Vector2(1280, 720),
	Vector2(2560, 1080),
	Vector2(900, 1400),
	Vector2(600, 400),
]

## Candidate art canvases, including one far wider than 16:9 and one square.
const FIT_ART := [
	Vector2(1920, 1080),
	Vector2(2560, 1080),
	Vector2(2048, 2048),
]

## Slack allowed on the coverage arithmetic. Dividing and re-multiplying sizes
## lands a hair under the exact value - 1400/1080*1080 is 1399.9999 - and that is
## a rounding artefact, not a gap. Two orders of magnitude under a pixel.
const EPS := 0.01

var main_menu: CanvasLayer


func before_test() -> void:
	main_menu = load(MAIN_SCENE_PATH).instantiate()
	add_child(main_menu)


func after_test() -> void:
	if is_instance_valid(main_menu):
		main_menu.queue_free()
		main_menu = null
	collect_orphan_node_details()


func _layer(layer_name: String) -> MenuParallaxLayer:
	return main_menu.get_node(layer_name) as MenuParallaxLayer


# --- the layer stack --------------------------------------------------------


func test_menu_has_three_layers_behind_the_buttons() -> void:
	var names: Array[String] = []
	for child in main_menu.get_children():
		if child is MenuParallaxLayer:
			names.append(String(child.name))

	assert_array(names).contains_exactly(["FarLayer", "MidLayer", "NearLayer"])
	# Draw order is sibling order, so the layers have to come before the button
	# Control or they paint over it. `Control` is asserted rather than named by
	# index so the existing menu test keeps its grip on it.
	assert_int(main_menu.get_children().find(main_menu.get_node("Control"))).is_greater(2)


func test_layers_are_far_to_near_in_draw_order() -> void:
	# Near over mid over far. If this inverts the depth reads backwards and
	# nothing else in the stack would show it.
	assert_int(main_menu.get_node("FarLayer").get_index()).is_less(
		main_menu.get_node("MidLayer").get_index())
	assert_int(main_menu.get_node("MidLayer").get_index()).is_less(
		main_menu.get_node("NearLayer").get_index())


func test_layer_motion_matches_the_planned_depth_ramp() -> void:
	for layer_name in EXPECTED_LAYERS:
		var layer := _layer(layer_name)
		assert_that(layer).override_failure_message(
			"%s is missing or is not a MenuParallaxLayer" % layer_name).is_not_null()
		var want: Array = EXPECTED_LAYERS[layer_name]
		assert_float(layer.travel).override_failure_message(
			"%s sway travel changed" % layer_name).is_equal_approx(want[0], 0.001)
		assert_float(layer.sway_period).override_failure_message(
			"%s sway period changed" % layer_name).is_equal_approx(want[1], 0.001)
		assert_float(layer.sway_phase).override_failure_message(
			"%s sway phase changed" % layer_name).is_equal_approx(want[2], 0.001)
		assert_float(layer.mouse_travel).override_failure_message(
			"%s mouse travel changed" % layer_name).is_equal_approx(want[3], 0.001)


func test_motion_ramp_increases_toward_the_camera() -> void:
	# A near layer that moves less than a far one reads as depth inverted, and
	# the scene has no other cue to contradict it.
	var far := _layer("FarLayer")
	var mid := _layer("MidLayer")
	var near := _layer("NearLayer")
	assert_float(mid.margin).is_greater(far.margin)
	assert_float(near.margin).is_greater(mid.margin)
	# ...and slower is further away, so the far layer must have the longest period.
	assert_float(far.sway_period).is_greater(mid.sway_period)
	assert_float(mid.sway_period).is_greater(near.sway_period)


func test_periods_are_all_different() -> void:
	# Three layers on the same period with different amplitudes read as one
	# rigid object. Coprime-ish periods make the loop long enough that the
	# pattern does not visibly repeat.
	var periods: Array[float] = []
	for layer_name in EXPECTED_LAYERS:
		periods.append(_layer(layer_name).sway_period)
	for i in periods.size():
		for j in range(i + 1, periods.size()):
			assert_bool(is_equal_approx(periods[i], periods[j])).override_failure_message(
				"%s and the layer at index %d share a %ss period"
				% [EXPECTED_LAYERS.keys()[i], j, periods[i]]
			).is_false()


func test_layers_do_not_take_mouse_input() -> void:
	# The layers sit behind the buttons and must not eat a click meant for one,
	# nor should the nearest layer grab hover the button underneath needs.
	for layer_name in EXPECTED_LAYERS:
		var layer := _layer(layer_name)
		assert_int(layer.mouse_filter).override_failure_message(
			"%s must not intercept the mouse" % layer_name
		).is_equal(Control.MOUSE_FILTER_IGNORE)
		for child in layer.get_children():
			assert_int((child as Control).mouse_filter).override_failure_message(
				"%s art must not intercept the mouse" % layer_name
			).is_equal(Control.MOUSE_FILTER_IGNORE)


# --- cover-fit --------------------------------------------------------------


func test_cover_fit_leaves_room_for_the_whole_horizontal_travel() -> void:
	# The whole point of the fit. A layer fitted to the bare window is exactly
	# as wide as the window, so the first pixel of sway uncovers a gap.
	for viewport: Vector2 in FIT_SIZES:
		for art: Vector2 in FIT_ART:
			var margin := 106.0
			var fitted := MenuParallaxLayer.cover_fit(art, viewport, margin)
			var message := "art %s into %s with %s margin" % [art, viewport, margin]
			assert_float(fitted.size.x).override_failure_message(
				"not wide enough to cover the window plus travel: " + message
			).is_greater_equal(viewport.x + margin * 2.0 - EPS)
			assert_float(fitted.size.y).override_failure_message(
				"not tall enough to cover the window: " + message
			).is_greater_equal(viewport.y - EPS)


func test_cover_fit_centres_the_art() -> void:
	# Centring is what puts the travel slack on both sides instead of all of it
	# on one, which is what makes the sway symmetric in both directions.
	for viewport: Vector2 in FIT_SIZES:
		for art: Vector2 in FIT_ART:
			var fitted := MenuParallaxLayer.cover_fit(art, viewport, 64.0)
			var centred := (viewport - fitted.size) * 0.5
			assert_vector(fitted.position).override_failure_message(
				"art %s into %s is not centred" % [art, viewport]
			).is_equal_approx(centred, Vector2(0.01, 0.01))


func test_no_gap_at_either_edge_across_the_whole_sway_range() -> void:
	# The invariant the layer's own `margin` exists to protect. Checked by
	# sweeping the sway rather than at the endpoints, because the ends are where
	# a sliver first appears and the middle hides it.
	for layer_name in EXPECTED_LAYERS:
		var layer := _layer(layer_name)
		for viewport: Vector2 in FIT_SIZES:
			var art := layer.art_size()
			var fitted := MenuParallaxLayer.cover_fit(art, viewport, layer.margin)
			var steps := 64
			for step in steps + 1:
				var shift := lerpf(-layer.margin, layer.margin, float(step) / float(steps))
				var moved := Rect2(fitted.position + Vector2(shift, 0.0), fitted.size)
				var message := "%s at shift %s in %s" % [layer_name, shift, viewport]
				assert_float(moved.position.x).override_failure_message(
					"gap down the left edge: " + message).is_less_equal(EPS)
				assert_float(moved.end.x).override_failure_message(
					"gap down the right edge: " + message
				).is_greater_equal(viewport.x - EPS)
				# No vertical sway, so vertically it only has to cover, not slide.
				assert_float(moved.position.y).override_failure_message(
					"gap at the top: " + message).is_less_equal(EPS)
				assert_float(moved.end.y).override_failure_message(
					"gap at the bottom: " + message).is_greater_equal(viewport.y - EPS)


func test_required_art_width_accounts_for_travel_on_both_sides() -> void:
	# The number step 4 bakes the transparent overscan to. Travel plus mouse
	# nudge, on both sides - the plan said 1720px while ignoring the mouse, which
	# was 44px short for the near layer.
	var widest: float = 0.0
	for layer_name in EXPECTED_LAYERS:
		widest = maxf(widest, _layer(layer_name).margin)
	assert_float(MenuParallaxLayer.required_art_width(VIEWPORT.x, widest)).is_equal(
		1764.0)


func test_layers_refit_when_the_layer_is_resized() -> void:
	# A full-rect Control under a CanvasLayer resizes with the window. Resizing
	# the layer directly exercises the same `resized` path without depending on
	# the root Window accepting a new size under a test runner.
	#
	# The size is set deferred because the layer's opposite anchors are unequal:
	# assigning `size` straight on a Control like that is overridden after
	# `_ready()` and Godot warns about it. Deferring is also what a real window
	# resize does, so this is the more faithful path, not just the quiet one.
	var near := _layer("NearLayer")
	var original := near.size
	var rect_before := near.art_rect().size

	near.set_deferred("size", Vector2(900, 1400))
	await await_millis(1)

	assert_vector(near.art_rect().size).override_failure_message(
		"the layer did not refit to its new size").is_not_equal(rect_before)
	assert_float(near.art_rect().size.y).override_failure_message(
		"the refitted layer does not cover its new height").is_greater_equal(1400.0 - EPS)
	assert_float(near.art_rect().size.x).override_failure_message(
		"the refitted layer left no room for its own sway").is_greater_equal(
		900.0 + near.margin * 2.0 - EPS)

	near.set_deferred("size", original)
	await await_millis(1)


func test_set_shift_is_clamped_to_the_reserved_slack() -> void:
	# Overshooting the margin is the one thing that puts a gap on screen, so the
	# clamp belongs here rather than only in the driver.
	var far := _layer("FarLayer")
	far.set_shift(9999.0)
	assert_float(far.get_shift()).override_failure_message(
		"set_shift did not clamp to the cover-fit slack").is_equal(far.margin)
	far.set_shift(-9999.0)
	assert_float(far.get_shift()).is_equal(-far.margin)
	far.set_shift(0.0)


func test_art_rect_moves_with_the_shift_and_nothing_else() -> void:
	var far := _layer("FarLayer")
	var rect_before := far.art_rect()
	far.set_shift(12.0)
	var rect_after := far.art_rect()

	assert_vector(rect_after.size).override_failure_message(
		"shifting must not rescale the art").is_equal(rect_before.size)
	assert_vector(rect_after.position - rect_before.position).override_failure_message(
		"the shift must be horizontal and 1:1 in pixels").is_equal(Vector2(12.0, 0.0))


# --- sway motion ------------------------------------------------------------


func test_sway_stays_inside_its_travel_budget() -> void:
	for layer_name in EXPECTED_LAYERS:
		var layer := _layer(layer_name)
		for step in 4096:
			var t := float(step) * layer.sway_period / 4096.0
			var offset := layer.sway_at(t)
			assert_float(absf(offset)).override_failure_message(
				"%s swayed %s px, past its %s px travel"
				% [layer_name, offset, layer.travel]
			).is_less_equal(layer.travel + 0.001)


func test_sway_actually_reaches_both_ends() -> void:
	# A layer that never travels looks identical to a static background, which
	# is the failure that would not show up as an error anywhere.
	for layer_name in EXPECTED_LAYERS:
		var layer := _layer(layer_name)
		var peak := 0.0
		for step in 2048:
			var t := float(step) * layer.sway_period / 2048.0
			peak = maxf(peak, absf(
				MenuParallaxLayer.sway_offset(layer.travel, layer.sway_period, t)))
		assert_float(peak).override_failure_message(
			"%s only reached %s px of its %s px travel"
			% [layer_name, peak, layer.travel]
		).is_greater_equal(layer.travel * 0.99)


func test_sway_dwells_at_the_turns_instead_of_bouncing() -> void:
	# The eased curve is flat at the extremes, so a layer arrives slowly and
	# leaves slowly. A bounce reads as a glitch; a hard stop reads as a stutter.
	# The turns are at the start of the cycle and at its halfway point.
	var travel := 48.0
	var period := 10.0
	var at_rest := MenuParallaxLayer.sway_offset(travel, period, period * 0.5)
	var just_past := MenuParallaxLayer.sway_offset(travel, period, period * 0.5 + 0.02)
	assert_float(at_rest).is_greater_equal(0.0)
	assert_float(absf(at_rest - just_past)).override_failure_message(
		"the layer moved %s px in 20ms at the turnaround"
		% absf(at_rest - just_past)
	).is_less(0.5)


func test_sway_is_periodic() -> void:
	# Restarting the menu must not restart the cycle mid-drift.
	for layer_name in EXPECTED_LAYERS:
		var layer := _layer(layer_name)
		var period := layer.sway_period
		for step in 16:
			var t := float(step) * period / 16.0
			assert_float(
				MenuParallaxLayer.sway_offset(layer.travel, period, t)
			).is_equal_approx(
				MenuParallaxLayer.sway_offset(layer.travel, period, t + period * 3.0),
				0.001
			)


func test_layer_phases_put_the_layers_out_of_step() -> void:
	# Same motion, different phase is what makes two layers read as two
	# distances rather than one object wobbling.
	var offsets: Array[float] = []
	for layer_name in EXPECTED_LAYERS:
		offsets.append(_layer(layer_name).sway_at(0.0))
	for i in offsets.size():
		for j in range(i + 1, offsets.size()):
			assert_bool(absf(offsets[i] - offsets[j]) > 1.0).override_failure_message(
				"%s and %s sit at the same point of their cycle, so they read as one object"
				% [EXPECTED_LAYERS.keys()[i], EXPECTED_LAYERS.keys()[j]]
			).is_true()


func test_shift_never_moves_a_layer_vertically() -> void:
	# Vertical drift on a background layer reads as a camera bob or as a bug,
	# not as depth. The y of the fitted rect must not depend on the shift at all.
	for layer_name in EXPECTED_LAYERS:
		var layer := _layer(layer_name)
		# Fitted to whatever this window actually is, which under a test runner is
		# not the project viewport. `art_size` rather than `placeholder_size`, so
		# this keeps checking the real artwork once it is wired in.
		var settled := MenuParallaxLayer.cover_fit(layer.art_size(), layer.size, layer.margin)
		var base_y := layer.art_rect().position.y
		for step in 33:
			layer.set_shift(lerpf(-layer.margin, layer.margin, float(step) / 32.0))
			assert_float(layer.art_rect().position.y).override_failure_message(
				"%s drifted vertically at shift %s px"
				% [layer_name, layer.get_shift()]
			).is_equal(base_y)
		assert_float(base_y).override_failure_message(
			"%s is not fitted to the viewport at all" % layer_name
		).is_equal(settled.position.y)


# --- the artwork -------------------------------------------------------------


func test_every_layer_has_its_artwork_wired_in() -> void:
	# A layer with no texture falls back to `placeholder_size` and renders as a
	# flat rectangle, which looks like a deliberate choice rather than a missing
	# asset. Asserting the texture exists means the failure is a loud one.
	for layer_name in EXPECTED_LAYERS:
		var art := _layer(layer_name).get_node("Art") as TextureRect
		assert_that(art).override_failure_message(
			"%s art should be a TextureRect now the artwork exists" % layer_name
		).is_not_null()
		assert_that(art.texture).override_failure_message(
			"%s has no texture, so it renders as a flat placeholder" % layer_name
		).is_not_null()


func test_art_is_stretched_with_cover_semantics() -> void:
	# The layer sizes its own rect to the cover-fit, so a TextureRect in any
	# stretch mode other than fill would letterbox inside it and reintroduce the
	# gap the fit exists to prevent.
	for layer_name in EXPECTED_LAYERS:
		var art := _layer(layer_name).get_node("Art") as TextureRect
		assert_int(art.stretch_mode).override_failure_message(
			"%s art must fill the rect the cover-fit computed" % layer_name
		).is_equal(TextureRect.STRETCH_SCALE)
		assert_int(art.expand_mode).override_failure_message(
			"%s art must ignore its own size, or the fit cannot size it" % layer_name
		).is_equal(TextureRect.EXPAND_IGNORE_SIZE)


func test_artwork_is_wide_enough_to_pay_for_its_own_sway() -> void:
	# The invariant the art contract exists for, asserted against the shipped
	# pixels rather than against a number in a table. If this fails, the artwork
	# is narrower than the window plus the layer's travel and the sway will show a
	# gap - the one failure the whole rig is built to prevent.
	for layer_name in EXPECTED_LAYERS:
		var layer := _layer(layer_name)
		var width := layer.art_size().x
		var needed := MenuParallaxLayer.required_art_width(VIEWPORT.x, layer.margin)
		assert_float(width).override_failure_message(
			"%s artwork is %s px wide but needs %s px to cover the window plus its %s px margin"
			% [layer_name, width, needed, layer.margin]
		).is_greater_equal(needed - EPS)


func test_keyed_layers_have_transparent_overscan_baked_into_their_edges() -> void:
	# The mid and near art arrived as JPEGs, which have no alpha, so step 4 keyed
	# white to transparent. Without that they cannot composite over the far layer
	# at all. The outer `margin` columns have to be fully transparent or the sway
	# slides a hard edge across the window instead of showing backdrop.
	for layer_name in ["MidLayer", "NearLayer"]:
		var layer := _layer(layer_name)
		var image := (layer.get_node("Art") as TextureRect).texture.get_image()
		var margin: int = int(layer.margin)
		var width := image.get_width()
		# Explicit float divide then cast: plain `int / 2` is the int-division
		# warning, and letting the float land in an int-typed var is the
		# narrowing-conversion one.
		var middle_y := int(image.get_height() / 2.0)
		for side in 2:
			for offset in margin:
				var x: int = offset if side == 0 else width - 1 - offset
				assert_float(image.get_pixel(x, middle_y).a).override_failure_message(
					"%s column %d is not transparent, so the sway will show a hard edge"
					% [layer_name, x]
				).is_equal(0.0)


func test_far_layer_is_opaque_because_it_is_the_backdrop() -> void:
	# Nothing sits behind the far layer, so transparency in it is a hole showing
	# the clear colour rather than sky. It buys width instead of margin, which
	# `test_artwork_is_wide_enough_to_pay_for_its_own_sway` already covers.
	# Nothing sits behind the far layer, so any transparency in it is a hole
	# showing the clear colour rather than sky. It gets width instead of margin,
	# which `test_artwork_is_wide_enough_to_pay_for_its_own_sway` already covers.
	var far := _layer("FarLayer")
	var image := (far.get_node("Art") as TextureRect).texture.get_image()
	var transparent := 0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			if image.get_pixel(x, y).a < 1.0:
				transparent += 1
	assert_int(transparent).override_failure_message(
		"the far layer has %d transparent sample points, so the backdrop has holes"
		% transparent
	).is_equal(0)


func test_artwork_is_positioned_by_the_cover_fit_and_not_by_its_own_anchors() -> void:
	# The layer lays its art out explicitly every refit. If the TextureRect were
	# also laying itself out from anchors, the two would fight and the fit would
	# not be what is on screen.
	var near := _layer("NearLayer")
	var art := near.get_node("Art") as TextureRect
	var fitted := near.art_rect()
	assert_vector(art.position).override_failure_message(
		"the artwork is not laid out by the layer's cover-fit"
	).is_equal(fitted.position)
	# Approximate rather than exact: Godot rounds a Control's size to whole
	# pixels, and the cover-fit divides. The slack is the margin, which is far
	# bigger than a pixel of rounding.
	assert_vector(art.size).override_failure_message(
		"the artwork is not laid out by the layer's cover-fit"
	).is_equal_approx(fitted.size, Vector2(1.0, 1.0))
	# And the fit is sizing it from the texture, not from the old placeholder.
	assert_vector(near.art_size()).is_equal((art.texture as Texture2D).get_size())


# --- existing behaviour that must survive -----------------------------------


func test_options_menu_still_replaces_the_buttons_over_the_background() -> void:
	# `main_menu.gd` hides the button Control when options opens. The background
	# has to stay visible behind it, which is why the layers are siblings of
	# `Control` rather than children of it.
	main_menu._on_options_pressed()
	assert_bool(main_menu.get_node("Control").visible).is_false()
	for layer_name in EXPECTED_LAYERS:
		assert_bool(_layer(layer_name).visible).override_failure_message(
			"%s went hidden with the buttons" % layer_name).is_true()