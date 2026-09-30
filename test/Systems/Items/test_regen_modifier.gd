# GdUnit TestSuite for the split flat / percent regen modifiers sharing the
# regen_modifier.gd base (timer + tick + stack scaling).
class_name RegenModifierTest
extends GdUnitTestSuite

const FLAT_REGEN := preload("res://src/Systems/Items/modifiers/flat_regen_modifier.gd")
const PERCENT_REGEN := preload("res://src/Systems/Items/modifiers/percent_regen_modifier.gd")


## Counts bus events. The listener has to be a one-argument lambda: the contract
## check rejects `Callable(...).bind(name)` because bind raises the arity to 2.
class EventCounter extends RefCounted:
	var counts: Dictionary = {}

	func watch(em: EventManager, event_name: String) -> void:
		counts[event_name] = 0
		em.subscribe(event_name, func(_event: Dictionary) -> void:
			counts[event_name] = int(counts.get(event_name, 0)) + 1)

	func get_count(event_name: String) -> int:
		return int(counts.get(event_name, 0))


func _build_holder(with_health: bool = true, max_health: float = 100.0) -> Node:
	var holder := Node.new()
	holder.name = "Holder"
	var event_manager := EventManager.new()
	event_manager.name = "EventManager"
	holder.add_child(event_manager)
	var stats := Stats.new()
	stats.name = "Stats"
	stats.event_manager = event_manager
	holder.add_child(stats)
	if with_health:
		stats.set_base_stat("health", max_health)
		var health := Health.new()
		health.name = "Health"
		health.event_manager = event_manager
		holder.add_child(health)
	add_child(holder)
	return holder


func _attach(holder: Node, modifier: Node) -> void:
	holder.add_child(modifier)
	modifier.add_stack(true)
	modifier.attachEventManager(holder.get_node("EventManager"))


func test_flat_regen_heals_flat_amount_per_tick() -> void:
	var holder := _build_holder()
	var health: Health = holder.get_node("Health")
	health.current_health = 50.0
	var modifier := FLAT_REGEN.new()
	modifier.health_delta = 4.0
	_attach(holder, modifier)

	modifier._on_regen_tick()
	assert_float(health.current_health).is_equal(54.0)
	holder.free()


func test_flat_regen_scales_by_active_stacks() -> void:
	var holder := _build_holder()
	var health: Health = holder.get_node("Health")
	health.current_health = 50.0
	var modifier := FLAT_REGEN.new()
	modifier.health_delta = 4.0
	holder.add_child(modifier)
	modifier.add_stack(true)
	modifier.add_stack(true)
	modifier.attachEventManager(holder.get_node("EventManager"))

	modifier._on_regen_tick()
	assert_float(health.current_health).is_equal(58.0)
	holder.free()


func test_percent_regen_heals_percent_of_max_health_per_tick() -> void:
	var holder := _build_holder(true, 200.0)
	var health: Health = holder.get_node("Health")
	health.current_health = 50.0
	var modifier := PERCENT_REGEN.new()
	modifier.health_delta_percent = 0.01
	_attach(holder, modifier)

	modifier._on_regen_tick()
	assert_float(health.current_health).is_equal(52.0)
	holder.free()


func test_percent_regen_scales_by_active_stacks_against_health() -> void:
	var holder := _build_holder(true, 100.0)
	var health: Health = holder.get_node("Health")
	health.current_health = 50.0
	var modifier := PERCENT_REGEN.new()
	modifier.health_delta_percent = 0.01
	holder.add_child(modifier)
	modifier.add_stack(true)
	modifier.add_stack(false)
	modifier.attachEventManager(holder.get_node("EventManager"))

	modifier._on_regen_tick()
	assert_float(health.current_health).is_equal(51.0)
	holder.free()


func test_tick_uses_get_health_and_skips_without_health() -> void:
	var holder := _build_holder(false)
	var modifier := FLAT_REGEN.new()
	holder.add_child(modifier)
	modifier.add_stack(true)
	modifier.attachEventManager(holder.get_node("EventManager"))
	# Must not crash when the holder has no Health node.
	modifier._on_regen_tick()
	holder.free()


# --- negative half: a signed delta drains instead of healing ---------------------

func test_negative_flat_delta_drains_health() -> void:
	var holder := _build_holder()
	var health: Health = holder.get_node("Health")
	health.current_health = 50.0
	var modifier := FLAT_REGEN.new()
	modifier.health_delta = -4.0
	_attach(holder, modifier)

	modifier._on_regen_tick()
	assert_float(health.current_health).is_equal(46.0)
	holder.free()


func test_negative_percent_delta_drains_percent_of_max_health() -> void:
	var holder := _build_holder(true, 200.0)
	var health: Health = holder.get_node("Health")
	health.current_health = 50.0
	var modifier := PERCENT_REGEN.new()
	modifier.health_delta_percent = -0.01
	_attach(holder, modifier)

	modifier._on_regen_tick()
	assert_float(health.current_health).is_equal(48.0)
	holder.free()


func test_negative_delta_kills_through_the_damage_pipeline() -> void:
	var holder := _build_holder()
	var health: Health = holder.get_node("Health")
	health.current_health = 3.0
	var counter := EventCounter.new()
	var em: EventManager = holder.get_node("EventManager")
	counter.watch(em, "on_death")
	var modifier := FLAT_REGEN.new()
	modifier.health_delta = -4.0
	_attach(holder, modifier)

	modifier._on_regen_tick()
	# The whole point of routing through apply_damage: a drain must be able to
	# kill, and it must announce it exactly once.
	assert_bool(health.is_dead).is_true()
	assert_int(counter.get_count("on_death")).is_equal(1)
	holder.free()


func test_negative_delta_runs_the_defender_phase() -> void:
	var holder := _build_holder()
	var health: Health = holder.get_node("Health")
	health.current_health = 50.0
	var counter := EventCounter.new()
	var em: EventManager = holder.get_node("EventManager")
	counter.watch(em, "before_take_damage")
	counter.watch(em, "after_take_damage")
	var modifier := FLAT_REGEN.new()
	modifier.health_delta = -4.0
	_attach(holder, modifier)

	modifier._on_regen_tick()
	# Energy shield, armor, hit flash and damage numbers all hang off these two,
	# so a drain that skipped them would be invisible to half the combat UI.
	assert_int(counter.get_count("before_take_damage")).is_equal(1)
	assert_int(counter.get_count("after_take_damage")).is_equal(1)
	holder.free()


func test_negative_delta_never_emits_on_heal() -> void:
	var holder := _build_holder()
	var health: Health = holder.get_node("Health")
	health.current_health = 50.0
	var counter := EventCounter.new()
	counter.watch(holder.get_node("EventManager"), "on_heal")
	var modifier := FLAT_REGEN.new()
	modifier.health_delta = -4.0
	_attach(holder, modifier)

	modifier._on_regen_tick()
	# Healing by a negative amount would fire on_heal with a negative payload and
	# read as a gain to every heal listener.
	assert_int(counter.get_count("on_heal")).is_zero()
	holder.free()


func test_negative_delta_never_emits_kill_rewards() -> void:
	var holder := _build_holder()
	var health: Health = holder.get_node("Health")
	health.current_health = 3.0
	var counter := EventCounter.new()
	counter.watch(holder.get_node("EventManager"), "on_kill")
	counter.watch(holder.get_node("EventManager"), "after_deal_damage")
	var modifier := FLAT_REGEN.new()
	modifier.health_delta = -4.0
	_attach(holder, modifier)

	modifier._on_regen_tick()
	# There is no attacker, so nothing is emitted on an attacker's bus: the
	# holder must not pay itself StatOnKill rewards for dying to its own item.
	assert_int(counter.get_count("on_kill")).is_zero()
	assert_int(counter.get_count("after_deal_damage")).is_zero()
	holder.free()


func test_positive_delta_still_heals_and_fires_on_heal() -> void:
	var holder := _build_holder()
	var health: Health = holder.get_node("Health")
	health.current_health = 50.0
	var counter := EventCounter.new()
	counter.watch(holder.get_node("EventManager"), "on_heal")
	var modifier := FLAT_REGEN.new()
	modifier.health_delta = 4.0
	_attach(holder, modifier)

	modifier._on_regen_tick()
	assert_float(health.current_health).is_equal(54.0)
	assert_int(counter.get_count("on_heal")).is_equal(1)
	holder.free()


func test_negative_delta_scales_by_active_stacks() -> void:
	var holder := _build_holder()
	var health: Health = holder.get_node("Health")
	health.current_health = 50.0
	var modifier := FLAT_REGEN.new()
	modifier.health_delta = -4.0
	holder.add_child(modifier)
	modifier.add_stack(true)
	modifier.add_stack(true)
	modifier.attachEventManager(holder.get_node("EventManager"))

	modifier._on_regen_tick()
	assert_float(health.current_health).is_equal(42.0)
	holder.free()


func test_zero_delta_touches_neither_heal_nor_damage() -> void:
	var holder := _build_holder()
	var health: Health = holder.get_node("Health")
	health.current_health = 50.0
	var counter := EventCounter.new()
	counter.watch(holder.get_node("EventManager"), "on_heal")
	counter.watch(holder.get_node("EventManager"), "before_take_damage")
	var modifier := FLAT_REGEN.new()
	modifier.health_delta = 0.0
	_attach(holder, modifier)

	modifier._on_regen_tick()
	assert_float(health.current_health).is_equal(50.0)
	assert_int(counter.get_count("on_heal")).is_zero()
	assert_int(counter.get_count("before_take_damage")).is_zero()
	holder.free()