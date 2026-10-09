# GdUnit TestSuite for the buff / debuff tile: a fixed 32x32 icon plate with a
# stack badge, a duration arc, and a polarity border, with all detail hover-only.
class_name BuffTileTest
extends GdUnitTestSuite

const TILE_SCENE := "res://src/ui/BuffTile.tscn"
const TOOLTIP_SCENE := "res://src/ui/TooltipUi.tscn"


func _make_tile() -> BuffTile:
    var tile: BuffTile = load(TILE_SCENE).instantiate()
    add_child(tile)
    return tile


func _entry(modifiers: Dictionary = {"attack_speed": {"flat": 0.5}}) -> BuffEntry:
    var entry := BuffEntry.new()
    entry.modifiers = modifiers
    entry.duration = 3.0
    entry.remaining = 2.4
    return entry


func test_tile_is_a_fixed_size_icon_plate_with_a_badge_and_an_arc() -> void:
    var tile := _make_tile()
    tile.set_entry(_entry())

    # Fixed size, so a row of tiles stays aligned however many are active.
    assert_vector(tile.custom_minimum_size).is_equal(BuffTile.TILE_SIZE)
    # The art is built at the tile's own icon size rather than the generator's
    # 48px default, or it would overflow the plate.
    assert_vector((tile.icon_holder.get_child(0) as Control).custom_minimum_size).is_equal(
        BuffTile.ICON_SIZE)

    tile.free()


func test_tile_uses_the_shared_panel_look() -> void:
    var tile := _make_tile()

    # Same fill, radius, border weight and shadow as TooltipUi / ShopItemCard, so
    # a tile never reads as a bolted-on widget next to the cards.
    var style: StyleBoxFlat = tile.get_theme_stylebox("panel")
    assert_that(style).is_not_null()
    assert_bool(style.bg_color == ItemDisplayPanel.PANEL_BG).is_true()
    assert_int(style.corner_radius_top_left).is_equal(ItemDisplayPanel.PANEL_RADIUS)
    assert_int(style.border_width_left).is_equal(2)

    tile.free()


func test_a_buff_tile_has_a_green_border_and_a_debuff_tile_a_red_one() -> void:
    var tile := _make_tile()

    # Polarity is carried by the border, never by tinting the icon art (see
    # `docs/visual_style.md`), so a plain buff and a plain debuff differ only here.
    tile.set_entry(_entry())
    assert_bool((tile.get_theme_stylebox("panel") as StyleBoxFlat).border_color
        == ItemDisplayPanel.COLOR_POSITIVE).is_true()

    var debuff_entry := _entry({"armor": {"flat": -10.0}})
    debuff_entry.is_debuff = true
    tile.set_entry(debuff_entry)
    assert_bool((tile.get_theme_stylebox("panel") as StyleBoxFlat).border_color
        == ItemDisplayPanel.COLOR_NEGATIVE).is_true()

    tile.free()


func test_hover_turns_the_border_gold_on_either_row() -> void:
    var tile := _make_tile()
    tile.set_entry(_entry())

    tile.set_hovered(true)
    assert_bool((tile.get_theme_stylebox("panel") as StyleBoxFlat).border_color
        == BuffTile.HOVER_BORDER).override_failure_message(
        "hover must read gold, the same as a hovered shop card").is_true()

    tile.set_hovered(false)
    assert_bool((tile.get_theme_stylebox("panel") as StyleBoxFlat).border_color
        == ItemDisplayPanel.COLOR_POSITIVE).is_true()

    tile.free()


func test_the_stack_badge_is_hidden_at_one_stack_and_shows_the_count_above_it() -> void:
    var tile := _make_tile()

    # A `1` on every tile is noise, and IconCard already sets the precedent of
    # hiding a redundant readout.
    var one := _entry()
    tile.set_entry(one)
    assert_bool(tile.stack_badge.visible).is_false()

    one.stack_count = 3
    tile.set_entry(one)
    assert_bool(tile.stack_badge.visible).is_true()
    assert_str(tile.stack_badge.text).is_equal("3")

    tile.free()


func test_a_second_stack_lands_without_rebuilding_the_tile() -> void:
    var tile := _make_tile()
    var entry := _entry()
    entry.stack_count = 1
    tile.set_entry(entry)
    assert_bool(tile.stack_badge.visible).is_false()

    # `tick()` is the per-frame path, so the badge has to be able to appear on a
    # stack that lands without the grid rebuilding the entry from scratch.
    entry.stack_count = 2
    tile.tick()
    assert_bool(tile.stack_badge.visible).is_true()
    assert_str(tile.stack_badge.text).is_equal("2")

    tile.free()


func test_a_multi_stat_buff_composites_every_stat_it_touches() -> void:
    var tile := _make_tile()
    tile.set_entry(_entry({"armor": {"flat": 3.0}, "attack_speed": {"flat": 0.5}}))

    # Two icons means the composite grid path, not a single TextureRect. This is
    # how a buff with no dedicated art of its own still shows both stats. The
    # generator wraps its grid in a plain Control, so the grid is one level down.
    var icon: Control = tile.icon_holder.get_child(0)
    var grid := icon.get_child(0)
    assert_that(grid).is_instanceof(GridContainer)
    assert_int((grid as GridContainer).get_child_count()).is_equal(2)

    tile.free()


func test_the_arc_is_hidden_without_a_running_timer_and_swept_by_remaining_time() -> void:
    var tile := _make_tile()

    # A buff with nothing counting must not claim to be at full: hidden beats a
    # full ring.
    var untimed := _entry()
    untimed.duration = 0.0
    untimed.remaining = 0.0
    tile.set_entry(untimed)
    assert_bool(tile.arc.visible).is_false()

    var timed := _entry()
    timed.duration = 4.0
    timed.remaining = 1.0
    tile.set_entry(timed)
    assert_bool(tile.arc.visible).is_true()
    assert_float(tile.arc.fraction).is_equal(0.25)

    tile.free()


func test_the_arc_turns_red_when_the_buff_is_about_to_lapse() -> void:
    var tile := _make_tile()
    var entry := _entry()
    entry.duration = 10.0
    entry.remaining = 8.0
    tile.set_entry(entry)

    # The tile holds the entry it was last given, so the per-frame path reads the
    # live numbers off it rather than being told them again.
    tile.tick()
    assert_bool(tile.arc.color == ItemDisplayPanel.COLOR_NEGATIVE).override_failure_message(
        "8s of 10s left must not read as expiring").is_false()

    entry.remaining = 1.0
    tile.tick()
    assert_bool(tile.arc.color == ItemDisplayPanel.COLOR_NEGATIVE).override_failure_message(
        "1s of 10s left must turn the arc red without reading the tooltip").is_true()

    tile.free()


func test_the_arc_turns_offscreen_and_off_with_the_tile() -> void:
    var tile := _make_tile()
    tile.set_entry(_entry())

    # `mouse_filter = IGNORE` on every part of the tile, so the opaque plate is
    # the hover target rather than a hole in the middle of it.
    assert_int(tile.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
    assert_int(tile.icon_holder.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
    assert_int((tile.icon_holder.get_child(0) as Control).mouse_filter).is_equal(
        Control.MOUSE_FILTER_IGNORE)
    assert_int(tile.stack_badge.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
    assert_int(tile.arc.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)

    tile.free()


func test_re_displaying_replaces_the_icon_instead_of_stacking_it() -> void:
    var tile := _make_tile()
    tile.set_entry(_entry())
    tile.set_entry(_entry())

    # A stale icon left queued for the end of the frame would stack a second one
    # on the first, so the plate must be freed immediately.
    assert_int(tile.icon_holder.get_child_count()).is_equal(1)

    tile.set_entry(null)
    assert_int(tile.icon_holder.get_child_count()).is_equal(0)
    assert_bool(tile.stack_badge.visible).is_false()
    assert_bool(tile.arc.visible).is_false()

    tile.free()


func test_hovering_the_whole_tile_opens_the_shared_tooltip_with_the_full_detail() -> void:
    var tooltip: TooltipUi = load(TOOLTIP_SCENE).instantiate()
    add_child(tooltip)
    var tile := _make_tile()
    var entry := _entry()
    entry.stack_count = 3
    entry.max_stacks = 10
    entry.trigger = "on_hit"
    entry.tooltip_text = "Your attacks come faster."
    tile.set_entry(entry)
    tooltip.bind_to_row_buff(tile, entry)

    assert_bool(tooltip.visible).is_false()
    tile.emit_signal("mouse_entered")
    assert_bool(tooltip.visible).is_true()

    # Header: the name and the row's own word.
    assert_str(tooltip.name_label.text).is_equal("Attack Speed")
    assert_bool(tooltip.type_badge.visible).is_true()
    assert_str(tooltip.type_badge.text).is_equal("Buff")

    # Body: the summed stat change, the stacks against the cap, the countdown,
    # the trigger and the effect's own sentence.
    assert_str(tooltip.label.text).contains("+0.5")
    assert_str(tooltip.label.text).contains("3 stacks (max 10)")
    assert_str(tooltip.label.text).contains("2.4s of 3.0s left")
    assert_str(tooltip.label.text).contains("Triggers on hit")
    assert_str(tooltip.label.text).contains("Your attacks come faster.")

    tile.emit_signal("mouse_exited")
    assert_bool(tooltip.visible).is_false()

    tile.free()
    tooltip.free()


func test_a_debuff_tooltip_says_debuff_and_keeps_the_stat_hints_explanation() -> void:
    var tooltip: TooltipUi = load(TOOLTIP_SCENE).instantiate()
    add_child(tooltip)
    var tile := _make_tile()

    var entry := _entry({"armor": {"flat": -10.0}})
    entry.is_debuff = true
    entry.trigger = "after_deal_damage"
    entry.duration = 3.0
    entry.remaining = 2.4
    tile.set_entry(entry)
    tooltip.bind_to_row_buff(tile, entry)
    tile.emit_signal("mouse_entered")

    assert_str(tooltip.type_badge.text).is_equal("Debuff")
    assert_str(tooltip.label.text).contains("-10.0")
    assert_str(tooltip.label.text).contains("Triggers on after deal damage")
    # The stat's own explanation travels with the hover, so a negative number the
    # player has never seen can be read without leaving the screen.
    assert_str(tooltip.label.text).contains(ItemTooltip.stat_hint("armor"))

    tile.free()
    tooltip.free()


func test_the_tile_draws_its_arc_without_a_scene_tree_hierarchy() -> void:
    var tile := _make_tile()
    var entry := _entry()
    entry.duration = 4.0
    entry.remaining = 2.0
    tile.set_entry(entry)

    # `_draw()` is the first CanvasItem custom draw in the UI layer, so it is
    # worth pinning that it runs at all: a zero-size arc node draws nothing and
    # the ring would silently vanish with no error anywhere. Deferred, because
    # the arc is full-rect anchored and Godot overrides an assigned `size` after
    # `_ready()`.
    tile.set_deferred("size", BuffTile.TILE_SIZE)
    tile.arc.set_deferred("size", BuffTile.TILE_SIZE)
    assert_float(tile.arc.fraction).is_equal(0.5)
    assert_float(tile.arc.margin).is_equal(BuffTile.ARC_MARGIN)
    assert_float(tile.arc.width).is_equal(BuffTile.ARC_WIDTH)

    tile.free()
