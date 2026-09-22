# GdUnit TestSuite for the shared BaseModifier stack contract and holder plumbing.
class_name BaseModifierTest
extends GdUnitTestSuite

const BASE := preload("res://src/Systems/Items/Modifiers/base_modifier.gd")

class RecordingModifier extends BaseModifier:
	var hook_calls: int = 0
	var hook_active_after: Array = []

	func _on_stacks_changed() -> void:
		hook_calls += 1
		hook_active_after.append(_active_stacks())


func _build_holder(with_stats: bool = true) -> Node:
	var holder := Node.new()
	holder.name = "Holder"
	var event_manager := EventManager.new()
	event_manager.name = "EventManager"
	holder.add_child(event_manager)
	if with_stats:
		var stats := Stats.new()
		stats.name = "Stats"
		stats.event_manager = event_manager
		holder.add_child(stats)
	add_child(holder)
	return holder


func _attach(holder: Node) -> BaseModifier:
	var modifier = BASE.new()
	holder.add_child(modifier)
	modifier._cache_holder(holder.get_node("EventManager"))
	return modifier


func test_active_stacks_floors_at_one_when_empty() -> void:
	var modifier = BASE.new()
	assert_int(modifier._active_stacks()).is_equal(1)
	modifier.free()


func test_add_stack_counts_only_active_entries() -> void:
	var modifier = BASE.new()
	modifier.add_stack(true)
	modifier.add_stack(false)
	modifier.add_stack(true)
	assert_int(modifier._active_stacks()).is_equal(2)
	modifier.free()


func test_set_stack_active_toggles_entry() -> void:
	var modifier = BASE.new()
	modifier.add_stack(true)
	modifier.add_stack(true)
	modifier.set_stack_active(1, false)
	assert_int(modifier._active_stacks()).is_equal(1)
	modifier.set_stack_active(0, false)
	assert_int(modifier._active_stacks()).is_equal(1)  # floor of 1
	modifier.free()


func test_set_stack_active_out_of_range_is_ignored() -> void:
	var modifier = BASE.new()
	modifier.add_stack(true)
	modifier.set_stack_active(5, false)
	assert_int(modifier._active_stacks()).is_equal(1)
	modifier.free()


func test_remove_stack_removes_entry() -> void:
	var modifier = BASE.new()
	modifier.add_stack(true)
	modifier.add_stack(true)
	modifier.remove_stack(0)
	assert_int(modifier._active_stacks()).is_equal(1)
	modifier.free()


func test_stacks_changed_hook_fires_on_bookkeeping() -> void:
	var modifier := RecordingModifier.new()
	add_child(modifier)
	modifier.add_stack(true)
	modifier.set_stack_active(0, true)
	modifier.remove_stack(0)
	assert_int(modifier.hook_calls).is_equal(3)
	assert_int(modifier.hook_active_after[2]).is_equal(1)
	modifier.free()


func test_cache_holder_populates_holder_and_stats() -> void:
	var holder := _build_holder()
	var modifier := _attach(holder)
	assert_that(modifier.holder).is_same(holder)
	assert_that(modifier.stats).is_same(holder.get_node("Stats"))
	holder.free()


func test_cache_holder_without_stats_keeps_stats_null() -> void:
	var holder := _build_holder(false)
	var modifier := _attach(holder)
	assert_that(modifier.holder).is_same(holder)
	assert_that(modifier.stats).is_null()
	holder.free()


func test_get_health_returns_holder_health() -> void:
	var holder := _build_holder()
	var health := Health.new()
	health.name = "Health"
	health.event_manager = holder.get_node("EventManager")
	holder.add_child(health)
	var modifier := _attach(holder)
	assert_that(modifier.get_health()).is_same(health)
	holder.free()


func test_get_health_returns_null_without_health_node() -> void:
	var holder := _build_holder()
	var modifier := _attach(holder)
	assert_that(modifier.get_health()).is_null()
	holder.free()