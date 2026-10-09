# GdUnit TestSuite for `BuffEntry`, the presentation model behind one buff /
# debuff tile. Pure data: every test here runs without a scene tree, which is the
# reason this class exists separately from the `Control` that draws it.
class_name BuffEntryTest
extends GdUnitTestSuite


func _entry(modifiers: Dictionary = {}) -> BuffEntry:
    var entry := BuffEntry.new()
    entry.modifiers = modifiers
    return entry


# --- summing ------------------------------------------------------------------


func test_total_modifiers_sums_a_stack_set_so_the_tooltip_shows_the_real_change() -> void:
    var total := BuffEntry.total_modifiers([
       	{"attack_speed": {"flat": 0.5}},
       	{"attack_speed": {"flat": 0.5}},
       	{"attack_speed": {"flat": 0.5}},
   	])

    # Three stacks of +0.5 must read as +1.5, not +0.5. A per-stack readout is the
    # single easiest way for the tile and the number the stat actually moved by
    # to disagree.
    assert_float(float(total["attack_speed"]["flat"])).is_equal(1.5)


func test_total_modifiers_adds_flat_and_percent_independently() -> void:
    var total := BuffEntry.total_modifiers([
       	{"damage": {"flat": 4.0, "percent": 0.25}},
       	{"damage": {"percent": 0.25}},
   	])

    # The second stack carries no flat term, so the flat sum stays at one stack's
    # worth rather than being zeroed or double counted.
    assert_float(float(total["damage"]["flat"])).is_equal(4.0)
    assert_float(float(total["damage"]["percent"])).is_equal(0.5)


func test_total_modifiers_keeps_a_stat_only_some_stacks_touched() -> void:
    var total := BuffEntry.total_modifiers([
       	{"armor": {"flat": 2.0}, "attack_speed": {"flat": 0.5}},
       	{"armor": {"flat": 3.0}},
   	])

    assert_float(float(total["armor"]["flat"])).is_equal(5.0)
    assert_float(float(total["attack_speed"]["flat"])).is_equal(0.5)


func test_scaled_modifiers_multiplies_one_stack_payload_by_the_stack_count() -> void:
    # A `Buff` applies the same dictionary once per stack, so the tile's total is
    # the payload times the count - not the payload, and not a sum of identical
    # entries that happens to agree.
    var total := BuffEntry.scaled_modifiers({"attack_speed": {"flat": 0.5}}, 3)
    assert_float(float(total["attack_speed"]["flat"])).is_equal(1.5)

    # Every kind is scaled, not just `flat`.
    var mixed := BuffEntry.scaled_modifiers({"damage": {"flat": 4.0, "percent": 0.25}}, 2)
    assert_float(float(mixed["damage"]["flat"])).is_equal(8.0)
    assert_float(float(mixed["damage"]["percent"])).is_equal(0.5)


func test_scaled_modifiers_does_not_mutate_the_payload_it_was_given() -> void:
    var payload := {"armor": {"flat": 2.0}}
    BuffEntry.scaled_modifiers(payload, 4)

    # The tile holds this dictionary only as a snapshot; the live `Buff` must not
    # find its own config multiplied when the UI reads it.
    assert_float(float(payload["armor"]["flat"])).is_equal(2.0)


func test_total_modifiers_of_nothing_is_empty() -> void:
    assert_dict(BuffEntry.total_modifiers([])).is_empty()


func test_total_modifiers_ignores_non_dictionary_entries() -> void:
    # A freed node in the array would otherwise raise instead of contributing.
    var total := BuffEntry.total_modifiers([null, {"armor": {"flat": 1.0}}, 7])
    assert_float(float(total["armor"]["flat"])).is_equal(1.0)


# --- primary stat -------------------------------------------------------------


func test_primary_stat_is_the_first_key_in_sorted_order() -> void:
    # Unsorted input would pick whichever key the dictionary happened to hand
    # back, so the tile's icon could change between two frames of the same buff.
    assert_str(BuffEntry.primary_stat({"movement_speed": {}, "armor": {}})).is_equal("armor")
    assert_str(BuffEntry.primary_stat({"armor": {}, "movement_speed": {}})).is_equal("armor")


func test_primary_stat_is_stable_across_insertion_orders() -> void:
    var first := BuffEntry.primary_stat({"projectile_pierce": {}, "armor": {}, "damage": {}})
    var second := BuffEntry.primary_stat({"damage": {}, "projectile_pierce": {}, "armor": {}})
    assert_str(first).is_equal("armor")
    assert_str(second).is_equal(first)


func test_primary_stat_of_no_modifiers_is_empty() -> void:
    assert_str(BuffEntry.primary_stat({})).is_empty()


# --- the duration arc ---------------------------------------------------------


func test_arc_fraction_is_remaining_over_duration() -> void:
    var entry := _entry()
    entry.duration = 4.0
    entry.remaining = 1.0
    assert_float(entry.arc_fraction()).is_equal(0.25)


func test_arc_fraction_is_clamped_to_the_arc_not_the_number() -> void:
    var entry := _entry()
    entry.duration = 4.0
    entry.remaining = 9.0
    assert_float(entry.arc_fraction()).is_equal(1.0)
    entry.remaining = -3.0
    assert_float(entry.arc_fraction()).is_equal(0.0)


func test_a_buff_with_no_running_timer_has_no_arc() -> void:
    # duration 0 means "nothing is counting", which hides the arc. Drawing it
    # full would claim a buff is at its peak when nothing is timing it.
    var entry := _entry()
    entry.duration = 0.0
    entry.remaining = 0.0
    assert_float(entry.arc_fraction()).is_equal(0.0)


func test_an_expiring_buff_is_flagged_under_a_fifth_of_its_time() -> void:
    var entry := _entry()
    entry.duration = 10.0

    entry.remaining = 1.0
    assert_bool(entry.is_expiring()).override_failure_message(
        "1s of 10s left must read as expiring").is_true()

    entry.remaining = 1.5
    assert_bool(entry.is_expiring()).is_true()

    entry.remaining = 2.0
    assert_bool(entry.is_expiring()).override_failure_message(
        "2s of 10s left is exactly the threshold, not under it").is_false()

    entry.remaining = 8.0
    assert_bool(entry.is_expiring()).is_false()


func test_a_buff_with_no_timer_is_never_flagged_expiring() -> void:
    var entry := _entry()
    entry.duration = 0.0
    entry.remaining = 0.0
    assert_bool(entry.is_expiring()).override_failure_message(
        "no running timer means there is nothing to expire").is_false()


# --- naming -------------------------------------------------------------------


func test_resolved_name_prefers_the_effects_own_display_name() -> void:
    var entry := _entry({"attack_speed": {"flat": 0.5}})
    entry.name = "Haste"
    assert_str(entry.resolved_name()).is_equal("Haste")


func test_resolved_name_falls_back_to_the_humanized_primary_stat() -> void:
    # Every shipped buff `.tres` sets no display_name, so this is the path that
    # actually runs in the game.
    var entry := _entry({"movement_speed": {"flat": 1.0}})
    assert_str(entry.resolved_name()).is_equal("Movement Speed")


func test_resolved_name_with_no_modifiers_falls_back_to_the_row_word() -> void:
    assert_str(_entry().resolved_name()).is_equal("Buff")

    var debuff := _entry()
    debuff.is_debuff = true
    assert_str(debuff.resolved_name()).is_equal("Debuff")
