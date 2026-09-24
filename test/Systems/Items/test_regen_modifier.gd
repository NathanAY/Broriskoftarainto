# GdUnit TestSuite for the split flat / percent regen modifiers sharing the
# regen_modifier.gd base (timer + tick + stack scaling).
class_name RegenModifierTest
extends GdUnitTestSuite

const FLAT_REGEN := preload("res://src/Systems/Items/modifiers/flat_regen_modifier.gd")
const PERCENT_REGEN := preload("res://src/Systems/Items/modifiers/percent_regen_modifier.gd")


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
	modifier.heal_amount = 4.0
	_attach(holder, modifier)

	modifier._on_regen_tick()
	assert_float(health.current_health).is_equal(54.0)
	holder.free()


func test_flat_regen_scales_by_active_stacks() -> void:
	var holder := _build_holder()
	var health: Health = holder.get_node("Health")
	health.current_health = 50.0
	var modifier := FLAT_REGEN.new()
	modifier.heal_amount = 4.0
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
	modifier.heal_amount_percent = 0.01
	_attach(holder, modifier)

	modifier._on_regen_tick()
	assert_float(health.current_health).is_equal(52.0)
	holder.free()


func test_percent_regen_scales_by_active_stacks_against_health() -> void:
	var holder := _build_holder(true, 100.0)
	var health: Health = holder.get_node("Health")
	health.current_health = 50.0
	var modifier := PERCENT_REGEN.new()
	modifier.heal_amount_percent = 0.01
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