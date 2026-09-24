# GdUnit TestSuite for the shared BaseModifier stack contract and holder plumbing.
class_name BaseModifierTest
extends GdUnitTestSuite

const BASE := preload("res://src/Systems/Items/modifiers/base_modifier.gd")

class RecordingModifier extends BaseModifier:
	var hook_calls: int = 0
	var hook_active_after: Array = []

	func _on_stacks_changed() -> void:
		hook_calls += 1
		hook_active_after.append(_active_stacks())


# Deliberately guard-less: subscribes via _subscribe and counts on_hit events, so
# tests prove weapon scoping lives in BaseModifier, not in per-handler checks.
class ScopedProbe extends BaseModifier:
	var hits: int = 0

	func attachEventManager(em: Node) -> void:
		_cache_holder(em)
		_subscribe("on_hit", Callable(self, "_on_hit"))

	func _on_hit(_event: Dictionary) -> void:
		hits += 1


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


func _hit_event(weapon: Object) -> Dictionary:
	return {"weapon": weapon, "body": null, "damage_context": DamageContext.new()}


func test_unbound_subscription_tracks_every_weapon() -> void:
	var holder := _build_holder()
	var em: EventManager = holder.get_node("EventManager")
	var probe := ScopedProbe.new()
	holder.add_child(probe)
	probe.attachEventManager(em)

	em.emit_event("on_hit", _hit_event(Object.new()))
	assert_int(probe.hits).is_equal(1)
	em.emit_event("on_hit", _hit_event(Object.new()))
	assert_int(probe.hits).is_equal(2)

	probe.free()
	holder.free()


func test_bound_subscription_scopes_without_any_handler_guard() -> void:
	var holder := _build_holder()
	var em: EventManager = holder.get_node("EventManager")
	var weapon_a := Object.new()
	var weapon_b := Object.new()

	var probe := ScopedProbe.new()
	probe.bound_weapon = weapon_a
	holder.add_child(probe)
	probe.attachEventManager(em)

	# an event from another weapon must not reach the guard-less handler
	em.emit_event("on_hit", _hit_event(weapon_b))
	assert_int(probe.hits).is_equal(0)
	# an event without any weapon key (e.g. explosion/orb sources) must not either
	em.emit_event("on_hit", {"damage_context": DamageContext.new()})
	assert_int(probe.hits).is_equal(0)
	# an event from the bound weapon fires
	em.emit_event("on_hit", _hit_event(weapon_a))
	assert_int(probe.hits).is_equal(1)

	probe.free()
	holder.free()


func test_unsubscribe_all_detaches_bound_wrapped_listener() -> void:
	var holder := _build_holder()
	var em: EventManager = holder.get_node("EventManager")
	var weapon_a := Object.new()

	var probe := ScopedProbe.new()
	probe.bound_weapon = weapon_a
	holder.add_child(probe)
	probe.attachEventManager(em)

	em.emit_event("on_hit", _hit_event(weapon_a))
	assert_int(probe.hits).is_equal(1)

	probe._unsubscribe_all()
	em.emit_event("on_hit", _hit_event(weapon_a))
	assert_int(probe.hits).is_equal(1)

	probe.free()
	holder.free()