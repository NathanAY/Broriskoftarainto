# GdUnit TestSuite for items that carry both a helpful and a harmful effect.
#
# `Item.effect_scene` is an Array[PackedScene], so one item can hand the holder a
# positive and a negative behavior at the same time (a flat regen plus a life
# drain, say). These suites pin the three shapes that has to survive:
#
# 1. ONE item with a positive AND a negative modifier.
# 2. ONE item with a positive flat regen AND a negative regen, fighting each other.
# 3. TWO items, one carrying the positive regen and one the negative regen.
#
# The interesting property throughout is that the two halves live on SEPARATE
# nodes (ItemHolder dedups per scene) with independent stacks, so they must never
# cancel each other structurally - only numerically.
class_name PolarityItemEffectsTest
extends GdUnitTestSuite

const FLAT_REGEN_SCENE := "res://src/Systems/Items/modifiers/FlatRegenModifier.tscn"
const PERCENT_REGEN_SCENE := "res://src/Systems/Items/modifiers/PercentRegenModifier.tscn"
const FLAT_DRAIN_SCENE := "res://src/Systems/Items/modifiers/FlatLifeDrainModifier.tscn"
const PERCENT_DRAIN_SCENE := "res://src/Systems/Items/modifiers/PercentLifeDrainModifier.tscn"
const KNOCKBACK_SCENE := "res://src/Systems/Items/modifiers/KnockbackModifier.tscn"


func _build_holder(max_health: float = 100.0) -> Node:
	var holder := Node.new()
	holder.name = "Holder"
	var event_manager := EventManager.new()
	event_manager.name = "EventManager"
	holder.add_child(event_manager)
	var stats := Stats.new()
	stats.name = "Stats"
	stats.event_manager = event_manager
	holder.add_child(stats)
	stats.set_base_stat("health", max_health)
	var health := Health.new()
	health.name = "Health"
	health.event_manager = event_manager
	holder.add_child(health)
	var item_holder := ItemHolder.new()
	item_holder.name = "ItemHolder"
	holder.add_child(item_holder)
	add_child(holder)
	return holder


func _item(scenes: Array[PackedScene], modifiers: Dictionary = {}, item_name: String = "Polarity item") -> Item:
	var item := Item.new()
	item.name = item_name
	item.description = "A gift and a curse."
	item.effect_scene = scenes
	item.modifiers = modifiers
	return item


func _effect_node(holder: Node, scene_path: String) -> BaseModifier:
	for child in holder.get_node("ItemHolder").get_children():
		if child.scene_file_path == scene_path:
			return child as BaseModifier
	return null


## Records the failure and returns null instead of dereferencing a missing node,
## which would abort the whole run on a debugger break.
func _expect_effect_node(holder: Node, scene_path: String) -> BaseModifier:
	var effect := _effect_node(holder, scene_path)
	assert_that(effect).override_failure_message("no effect node for %s" % scene_path).is_not_null()
	return effect


## Every regen-shaped modifier exposes the same tick, so a test can drive the
## timers by hand instead of waiting on them.
func _tick(effect: BaseModifier) -> void:
	effect.call("_on_regen_tick")


# --- 1. one item, one positive modifier and one negative modifier --------------

func test_one_item_attaches_both_halves_as_separate_nodes() -> void:
	var holder := _build_holder()
	var item_holder: ItemHolder = holder.get_node("ItemHolder")

	item_holder.add_item(_item([load(KNOCKBACK_SCENE), load(FLAT_DRAIN_SCENE)], {}, "Cursed Knocker"))

	var knockback := _expect_effect_node(holder, KNOCKBACK_SCENE)
	var drain := _expect_effect_node(holder, FLAT_DRAIN_SCENE)
	if knockback == null or drain == null:
		holder.free()
		return
	# Distinct scenes must not collapse into one node, or picking the item up
	# twice would silently double one half and not the other.
	assert_that(knockback).is_not_same(drain)
	assert_int(knockback.stacks.size()).is_equal(1)
	assert_int(drain.stacks.size()).is_equal(1)
	assert_that(knockback.event_manager).is_not_null()
	assert_that(drain.event_manager).is_not_null()
	holder.free()


func test_one_item_gives_each_half_a_stack_per_copy() -> void:
	var holder := _build_holder()
	var item_holder: ItemHolder = holder.get_node("ItemHolder")
	var item := _item([load(FLAT_REGEN_SCENE), load(FLAT_DRAIN_SCENE)])

	item_holder.add_item(item)
	item_holder.add_item(item)

	var regen := _expect_effect_node(holder, FLAT_REGEN_SCENE)
	var drain := _expect_effect_node(holder, FLAT_DRAIN_SCENE)
	if regen == null or drain == null:
		holder.free()
		return
	assert_int(regen.stacks.size()).is_equal(2)
	assert_int(drain.stacks.size()).is_equal(2)
	holder.free()


func test_removing_a_both_halves_item_pops_both() -> void:
	var holder := _build_holder()
	var item_holder: ItemHolder = holder.get_node("ItemHolder")
	var item := _item([load(KNOCKBACK_SCENE), load(FLAT_DRAIN_SCENE)])

	item_holder.add_item(item)
	item_holder.add_item(item)
	item_holder.remove_item(item)

	var knockback := _expect_effect_node(holder, KNOCKBACK_SCENE)
	var drain := _expect_effect_node(holder, FLAT_DRAIN_SCENE)
	if knockback == null or drain == null:
		holder.free()
		return
	assert_int(knockback.stacks.size()).is_equal(1)
	assert_int(drain.stacks.size()).is_equal(1)

	item_holder.remove_item(item)
	# Last copy gone: neither half may survive as an orphaned timer.
	assert_bool(knockback.is_queued_for_deletion()).is_true()
	assert_bool(drain.is_queued_for_deletion()).is_true()
	holder.free()


# --- 2. one item, positive flat regen and negative regen together ---------------

func test_regen_and_drain_on_one_item_net_out_per_tick() -> void:
	var holder := _build_holder()
	var health: Health = holder.get_node("Health")
	health.current_health = 50.0
	var item_holder: ItemHolder = holder.get_node("ItemHolder")

	# The two halves are separate scenes with separate exported amounts.
	item_holder.add_item(_item([load(FLAT_REGEN_SCENE), load(FLAT_DRAIN_SCENE)], {}, "Cursed Charm"))
	var regen := _expect_effect_node(holder, FLAT_REGEN_SCENE)
	var drain := _expect_effect_node(holder, FLAT_DRAIN_SCENE)
	if regen == null or drain == null:
		holder.free()
		return
	regen.set("health_delta", 4.0)
	drain.set("health_delta", -2.0)

	_tick(regen)
	assert_float(health.current_health).is_equal(54.0)
	_tick(drain)
	assert_float(health.current_health).is_equal(52.0)
	assert_bool(health.is_dead).is_false()
	holder.free()


func test_regen_and_drain_on_one_item_each_scale_by_their_own_stacks() -> void:
	var holder := _build_holder()
	var health: Health = holder.get_node("Health")
	health.current_health = 50.0
	var item_holder: ItemHolder = holder.get_node("ItemHolder")
	var item := _item([load(FLAT_REGEN_SCENE), load(FLAT_DRAIN_SCENE)])

	item_holder.add_item(item)
	item_holder.add_item(item)
	var regen := _expect_effect_node(holder, FLAT_REGEN_SCENE)
	var drain := _expect_effect_node(holder, FLAT_DRAIN_SCENE)
	if regen == null or drain == null:
		holder.free()
		return
	regen.set("health_delta", 4.0)
	drain.set("health_delta", -2.0)

	# 50 + (4 * 2) - (2 * 2) = 54
	_tick(regen)
	_tick(drain)
	assert_float(health.current_health).is_equal(54.0)
	holder.free()


func test_drain_half_of_a_regen_item_still_kills() -> void:
	var holder := _build_holder()
	var health: Health = holder.get_node("Health")
	health.current_health = 3.0
	var item_holder: ItemHolder = holder.get_node("ItemHolder")

	item_holder.add_item(_item([load(FLAT_REGEN_SCENE), load(FLAT_DRAIN_SCENE)]))
	var regen := _expect_effect_node(holder, FLAT_REGEN_SCENE)
	var drain := _expect_effect_node(holder, FLAT_DRAIN_SCENE)
	if regen == null or drain == null:
		holder.free()
		return
	regen.set("health_delta", 10.0)
	drain.set("health_delta", -20.0)

	_tick(regen)
	assert_float(health.current_health).is_equal(13.0)
	_tick(drain)
	# The healing sibling must not put the death check off: the drain still
	# routes through apply_damage, so a dead holder latches and stays dead.
	assert_bool(health.is_dead).is_true()
	holder.free()


func test_dead_holder_is_immune_to_the_drain_half_but_still_heals() -> void:
	var holder := _build_holder()
	var health: Health = holder.get_node("Health")
	health.current_health = 3.0
	health.is_dead = true
	var item_holder: ItemHolder = holder.get_node("ItemHolder")

	item_holder.add_item(_item([load(FLAT_REGEN_SCENE), load(FLAT_DRAIN_SCENE)]))
	var regen := _expect_effect_node(holder, FLAT_REGEN_SCENE)
	var drain := _expect_effect_node(holder, FLAT_DRAIN_SCENE)
	if regen == null or drain == null:
		holder.free()
		return
	regen.set("health_delta", 5.0)
	drain.set("health_delta", -5.0)

	_tick(regen)
	# Health.heal() has no dead check, so regen keeps topping a corpse up; the
	# drain is rejected by apply_damage. Pinned because it is surprising.
	assert_float(health.current_health).is_equal(8.0)
	_tick(drain)
	assert_float(health.current_health).is_equal(8.0)
	holder.free()


func test_percent_and_flat_drain_on_one_item_both_apply() -> void:
	var holder := _build_holder(200.0)
	var health: Health = holder.get_node("Health")
	health.current_health = 100.0
	var item_holder: ItemHolder = holder.get_node("ItemHolder")

	# Two COST halves on one item: nothing forbids it, and both must fire.
	item_holder.add_item(_item([load(FLAT_DRAIN_SCENE), load(PERCENT_DRAIN_SCENE)], {}, "Doom Charm"))
	var flat_drain := _expect_effect_node(holder, FLAT_DRAIN_SCENE)
	var percent_drain := _expect_effect_node(holder, PERCENT_DRAIN_SCENE)
	if flat_drain == null or percent_drain == null:
		holder.free()
		return
	assert_int(int(flat_drain.get("effect_kind"))).is_equal(BaseModifier.EffectKind.COST)
	assert_int(int(percent_drain.get("effect_kind"))).is_equal(BaseModifier.EffectKind.COST)
	flat_drain.set("health_delta", -2.0)
	percent_drain.set("health_delta_percent", -0.01)

	# 100 - 2 - (200 * 0.01) = 96
	_tick(flat_drain)
	_tick(percent_drain)
	assert_float(health.current_health).is_equal(96.0)
	holder.free()


# --- 3. two items, one positive regen and one negative regen -------------------

func test_two_items_make_independent_nodes() -> void:
	var holder := _build_holder()
	var item_holder: ItemHolder = holder.get_node("ItemHolder")

	item_holder.add_item(_item([load(FLAT_REGEN_SCENE)], {}, "Warm Ring"))
	item_holder.add_item(_item([load(FLAT_DRAIN_SCENE)], {}, "Cold Ring"))

	var regen := _expect_effect_node(holder, FLAT_REGEN_SCENE)
	var drain := _expect_effect_node(holder, FLAT_DRAIN_SCENE)
	if regen == null or drain == null:
		holder.free()
		return
	assert_that(regen).is_not_same(drain)
	assert_int(regen.stacks.size()).is_equal(1)
	assert_int(drain.stacks.size()).is_equal(1)
	holder.free()


func test_two_items_tick_independently() -> void:
	var holder := _build_holder()
	var health: Health = holder.get_node("Health")
	health.current_health = 50.0
	var item_holder: ItemHolder = holder.get_node("ItemHolder")

	item_holder.add_item(_item([load(FLAT_REGEN_SCENE)], {}, "Warm Ring"))
	item_holder.add_item(_item([load(FLAT_DRAIN_SCENE)], {}, "Cold Ring"))
	var regen := _expect_effect_node(holder, FLAT_REGEN_SCENE)
	var drain := _expect_effect_node(holder, FLAT_DRAIN_SCENE)
	if regen == null or drain == null:
		holder.free()
		return
	regen.set("health_delta", 4.0)
	drain.set("health_delta", -2.0)

	_tick(regen)
	assert_float(health.current_health).is_equal(54.0)
	_tick(drain)
	assert_float(health.current_health).is_equal(52.0)
	holder.free()


func test_two_copies_of_only_the_drain_item_double_only_the_drain() -> void:
	var holder := _build_holder()
	var health: Health = holder.get_node("Health")
	health.current_health = 50.0
	var item_holder: ItemHolder = holder.get_node("ItemHolder")
	var drain_item := _item([load(FLAT_DRAIN_SCENE)], {}, "Cold Ring")

	item_holder.add_item(_item([load(FLAT_REGEN_SCENE)], {}, "Warm Ring"))
	item_holder.add_item(drain_item)
	item_holder.add_item(drain_item)

	var regen := _expect_effect_node(holder, FLAT_REGEN_SCENE)
	var drain := _expect_effect_node(holder, FLAT_DRAIN_SCENE)
	if regen == null or drain == null:
		holder.free()
		return
	assert_int(regen.stacks.size()).is_equal(1)
	assert_int(drain.stacks.size()).is_equal(2)
	regen.set("health_delta", 4.0)
	drain.set("health_delta", -2.0)

	# 50 + 4 - (2 * 2) = 50
	_tick(regen)
	_tick(drain)
	assert_float(health.current_health).is_equal(50.0)
	holder.free()


func test_removing_the_negative_item_leaves_the_positive_running() -> void:
	var holder := _build_holder()
	var health: Health = holder.get_node("Health")
	health.current_health = 50.0
	var item_holder: ItemHolder = holder.get_node("ItemHolder")
	var drain_item := _item([load(FLAT_DRAIN_SCENE)], {}, "Cold Ring")

	item_holder.add_item(_item([load(FLAT_REGEN_SCENE)], {}, "Warm Ring"))
	item_holder.add_item(drain_item)
	var regen := _expect_effect_node(holder, FLAT_REGEN_SCENE)
	var drain := _expect_effect_node(holder, FLAT_DRAIN_SCENE)
	if regen == null or drain == null:
		holder.free()
		return
	regen.set("health_delta", 4.0)
	drain.set("health_delta", -2.0)

	item_holder.remove_item(drain_item)
	# The drain node is gone, so nothing can subtract any more.
	assert_bool(drain.is_queued_for_deletion()).is_true()
	_tick(regen)
	assert_float(health.current_health).is_equal(54.0)
	holder.free()


func test_both_items_off_the_same_scene_share_one_node() -> void:
	var holder := _build_holder()
	var health: Health = holder.get_node("Health")
	health.current_health = 50.0
	var item_holder: ItemHolder = holder.get_node("ItemHolder")

	# Two DIFFERENT items carrying the SAME regen scene must dedup into one node
	# with two stacks - otherwise per-copy scaling would silently break.
	item_holder.add_item(_item([load(FLAT_REGEN_SCENE)], {}, "Warm Ring I"))
	item_holder.add_item(_item([load(FLAT_REGEN_SCENE)], {}, "Warm Ring II"))
	var regen := _expect_effect_node(holder, FLAT_REGEN_SCENE)
	if regen == null:
		holder.free()
		return
	assert_int(regen.stacks.size()).is_equal(2)
	regen.set("health_delta", 4.0)
	_tick(regen)
	assert_float(health.current_health).is_equal(58.0)
	holder.free()
