# GdUnit TestSuite for the display data a buff / debuff carries for the UI.
# Pure data plumbing: identity, the read-only stack / remaining-time accessors,
# and the `DebuffSource` -> `Debuff` back-reference the tile grid groups on.
class_name BuffDisplayDataTest
extends GdUnitTestSuite

const BUFF_SCENE := "res://src/Systems/Items/Buffs/buff.tscn"
const DEBUFF_SCENE := "res://src/Systems/Items/Buffs/DebuffSource.tscn"


## An entity root with the children `Buff._ready()` / `DebuffSource._ready()`
## look up, added to the test tree so its timers actually run. `hold_owner`
## resolves on access, so the wiring holds from the moment it is parented.
func _build_entity(entity_name: String) -> Node:
    var entity := Node.new()
    entity.name = entity_name

    var event_manager := EventManager.new()
    event_manager.name = "EventManager"
    entity.add_child(event_manager)

    var stats := Stats.new()
    stats.name = "Stats"
    stats.event_manager = event_manager
    entity.add_child(stats)

    var item_holder := ItemHolder.new()
    item_holder.name = "ItemHolder"
    entity.add_child(item_holder)

    add_child(entity)
    return entity


func _make_buff(holder: ItemHolder) -> Buff:
    var buff: Buff = load(BUFF_SCENE).instantiate()
    buff.duration = 4.0
    buff.modifiers = {"attack_speed": {"flat": 0.5}}
    holder.add_child(buff)
    return buff


func test_buff_exposes_a_display_name_and_tooltip_text_that_default_to_empty() -> void:
    var buff: Buff = load(BUFF_SCENE).instantiate()

    # Empty by default, so a buff `.tres` that sets neither still renders - the
    # UI falls back to the humanized primary stat.
    assert_str(buff.display_name).is_empty()
    assert_str(buff.tooltip_text).is_empty()

    buff.display_name = "Haste"
    buff.tooltip_text = "Your attacks come faster."
    assert_str(buff.display_name).is_equal("Haste")
    assert_str(buff.tooltip_text).is_equal("Your attacks come faster.")

    buff.free()


func test_debuff_source_carries_the_same_two_display_fields() -> void:
    var source: DebuffSource = load(DEBUFF_SCENE).instantiate()

    assert_str(source.display_name).is_empty()
    assert_str(source.tooltip_text).is_empty()

    source.display_name = "Rust"
    source.tooltip_text = "Armour is eaten away."
    assert_str(source.display_name).is_equal("Rust")
    assert_str(source.tooltip_text).is_equal("Armour is eaten away.")

    source.free()


func test_buff_stack_count_and_remaining_time_are_read_only_accessors() -> void:
    var holder_entity := _build_entity("Holder")
    var buff := _make_buff(holder_entity.get_node("ItemHolder"))

    # Nothing running yet: no stacks, and no remaining time to report.
    assert_int(buff.stack_count()).is_equal(0)
    assert_float(buff.remaining_time()).is_equal(0.0)

    var em: EventManager = holder_entity.get_node("EventManager")
    em.emit_event("on_hit", {"damage_context": DamageContext.new()})
    em.emit_event("on_hit", {"damage_context": DamageContext.new()})

    # The UI reads these instead of the private `_active_stacks`, so two triggers
    # on one buff node are one tile with a badge of 2.
    assert_int(buff.stack_count()).is_equal(2)
    var remaining := buff.remaining_time()
    assert_bool(remaining > 0.0).override_failure_message(
        "remaining_time() must read the running stack timers, not return 0"
    ).is_true()
    assert_bool(remaining <= buff.duration).is_true()

    holder_entity.free()


func test_buff_remaining_time_reports_the_soonest_stack_not_the_latest() -> void:
    var holder_entity := _build_entity("Holder")
    var buff := _make_buff(holder_entity.get_node("ItemHolder"))
    var em: EventManager = holder_entity.get_node("EventManager")

    # Two stacks half a second apart: the soonest one is what the tile's arc has
    # to run out by, so taking the max would show a buff as full after its first
    # stack had already lapsed.
    em.emit_event("on_hit", {"damage_context": DamageContext.new()})
    await get_tree().create_timer(0.5).timeout
    em.emit_event("on_hit", {"damage_context": DamageContext.new()})

    assert_int(buff.stack_count()).is_equal(2)
    assert_bool(buff.remaining_time() < buff.duration).override_failure_message(
        "the oldest stack started first, so remaining_time() must be under the full duration"
    ).is_true()

    holder_entity.free()


func test_debuff_records_its_source_and_the_timer_it_created() -> void:
    var source_entity := _build_entity("SourceHolder")
    var target_entity := _build_entity("TargetHolder")

    var source: DebuffSource = load(DEBUFF_SCENE).instantiate()
    source.duration = 2.0
    source.display_name = "Rust"
    source.tooltip_text = "Armour is eaten away."
    source_entity.get_node("ItemHolder").add_child(source)

    var debuff := Debuff.new()
    # The same argument list `DebuffSource._on_trigger()` uses.
    debuff.setup(source_entity, target_entity, {"armor": {"flat": -10.0}}, 2.0,
        source, "Rust", "Armour is eaten away.")
    target_entity.add_child(debuff)

    # The back-reference is the whole reason two instances of one curse can be
    # one tile; without it the UI has nothing to group on.
    assert_object(debuff.source).is_same(source)
    assert_str(debuff.display_name).is_equal("Rust")
    assert_str(debuff.tooltip_text).is_equal("Armour is eaten away.")

    # B3: the timer used to be parented to the *target* and kept no reference,
    # so the remaining-time lookup scanned the Debuff's children and always came
    # back empty. It is now a child of the instance and reachable directly.
    assert_object(debuff.timer).is_not_null()
    assert_int(debuff.timer.get_parent().get_instance_id()).is_equal(
        debuff.get_instance_id())
    assert_float(debuff.remaining_time()).is_greater(0.0)

    source_entity.free()
    target_entity.free()


func test_debuff_remaining_time_counts_down_and_the_timer_frees_itself() -> void:
    var source_entity := _build_entity("SourceHolder")
    var target_entity := _build_entity("TargetHolder")

    var source: DebuffSource = load(DEBUFF_SCENE).instantiate()
    source_entity.get_node("ItemHolder").add_child(source)

    var debuff := Debuff.new()
    debuff.setup(source_entity, target_entity, {"armor": {"flat": -10.0}}, 0.4, source)
    target_entity.add_child(debuff)

    var first := debuff.remaining_time()
    assert_bool(first > 0.0).is_true()
    await get_tree().create_timer(0.2).timeout
    var second := debuff.remaining_time()
    assert_bool(second < first).override_failure_message(
        "remaining_time() must fall as the debuff's own timer runs: %f -> %f" % [first, second]
    ).is_true()

    await get_tree().create_timer(0.4).timeout
    # Expiry frees the instance and its timer, so the instance no longer answers.
    assert_bool(is_instance_valid(debuff)).is_false()

    source_entity.free()
    target_entity.free()
