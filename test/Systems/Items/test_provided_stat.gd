# GdUnit TestSuite for modifiers owning a stat via `provided_stat`
# (claim/release presence + multiplier semantics; see docs/plans/dynamic-provided-stats.md).
class_name ProvidedStatTest
extends GdUnitTestSuite

const LIFE_LEACH_SCENE := "res://src/Systems/Items/modifiers/LifeLeachModifier.tscn"
const ARMOR_SCENE := "res://src/Systems/Items/modifiers/ArmorModifier.tscn"


func _build_holder() -> Node:
	var holder := Node.new()
	holder.name = "Holder"
	var event_manager := EventManager.new()
	event_manager.name = "EventManager"
	holder.add_child(event_manager)
	var stats := Stats.new()
	stats.name = "Stats"
	stats.event_manager = event_manager
	holder.add_child(stats)
	var health := Health.new()
	health.name = "Health"
	health.event_manager = event_manager
	holder.add_child(health)
	add_child(holder)
	return holder


func _attach_modifier(holder: Node, scene_path: String, stacks: int = 1) -> Node:
	var scene: PackedScene = load(scene_path)
	var modifier: Node = scene.instantiate()
	holder.add_child(modifier)
	modifier.attachEventManager(holder.get_node("EventManager"))
	for i in stacks:
		modifier.add_stack(true)
	return modifier


func test_provided_stat_installed_on_attach() -> void:
	var holder := _build_holder()
	var stats: Stats = holder.get_node("Stats")
	_attach_modifier(holder, LIFE_LEACH_SCENE)
	assert_bool(stats.stats.has("lifeleach")).is_true()
	assert_float(float(stats.stats.get("lifeleach", 0.0))).is_equal(1.0)
	holder.free()


func test_provided_stat_released_on_detach() -> void:
	var holder := _build_holder()
	var stats: Stats = holder.get_node("Stats")
	var modifier := _attach_modifier(holder, LIFE_LEACH_SCENE)
	assert_bool(stats.stats.has("lifeleach")).is_true()
	modifier.remove_latest_stack()
	assert_bool(stats.stats.has("lifeleach")).is_false()
	holder.free()


func test_provided_stat_refcounted_across_installations() -> void:
	var holder := _build_holder()
	var stats: Stats = holder.get_node("Stats")
	stats.claim_provided_stat("lifeleach", 1.0)
	stats.claim_provided_stat("lifeleach", 1.0)
	assert_bool(stats.stats.has("lifeleach")).is_true()
	stats.release_provided_stat("lifeleach")
	assert_bool(stats.stats.has("lifeleach")).is_true()
	stats.release_provided_stat("lifeleach")
	assert_bool(stats.stats.has("lifeleach")).is_false()
	holder.free()


func test_multiplier_composes_with_stat_modifiers() -> void:
	var holder := _build_holder()
	var stats: Stats = holder.get_node("Stats")
	var health: Health = holder.get_node("Health")
	var em: EventManager = holder.get_node("EventManager")
	_attach_modifier(holder, LIFE_LEACH_SCENE, 2)
	stats.add_modifier({"lifeleach": {"flat": 0.5}})
	var dmg := DamageContext.new()
	dmg.final_amount = 10.0
	health.take_damage(dmg)
	var health_before: float = health.current_health
	var hit := DamageContext.new()
	hit.final_amount = 20.0
	em.emit_event("on_hit", {"damage_context": hit})
	# 0.05 * 2 * 1.5 * 20 = 3.0 heal
	assert_float(health.current_health).is_equal(health_before + 3.0)
	holder.free()


func test_negative_stat_loses_health() -> void:
	var holder := _build_holder()
	var stats: Stats = holder.get_node("Stats")
	var health: Health = holder.get_node("Health")
	var em: EventManager = holder.get_node("EventManager")
	_attach_modifier(holder, LIFE_LEACH_SCENE)
	stats.add_modifier({"lifeleach": {"flat": -2.0}})
	var dmg := DamageContext.new()
	dmg.final_amount = 10.0
	health.take_damage(dmg)
	var health_before: float = health.current_health
	var hit := DamageContext.new()
	hit.final_amount = 100.0
	em.emit_event("on_hit", {"damage_context": hit})
	# multiplier -1.0 -> heal(-5.0) -> current_health drops by 5
	assert_float(health.current_health).is_equal(health_before - 5.0)
	holder.free()


func test_on_hit_heals_from_provided_stat() -> void:
	var holder := _build_holder()
	var health: Health = holder.get_node("Health")
	var em: EventManager = holder.get_node("EventManager")
	_attach_modifier(holder, LIFE_LEACH_SCENE)
	var dmg := DamageContext.new()
	dmg.final_amount = 10.0
	health.take_damage(dmg)
	var health_before: float = health.current_health
	var hit := DamageContext.new()
	hit.final_amount = 100.0
	em.emit_event("on_hit", {"damage_context": hit})
	assert_float(health.current_health).is_equal(health_before + 5.0)
	holder.free()


func test_armor_reads_stat_and_is_not_owned() -> void:
	var holder := _build_holder()
	var stats: Stats = holder.get_node("Stats")
	stats.set_base_stat("armor", 10.0)
	var modifier := _attach_modifier(holder, ARMOR_SCENE)
	var before_keys: Array = stats.stats.keys()
	modifier.remove_latest_stack()
	# armor pre-exists -> not claimed/released by the modifier
	assert_bool(stats.stats.has("armor")).is_true()
	assert_int(stats.stats.keys().size()).is_equal(before_keys.size())
	holder.free()


func test_remove_item_detaches_stat_and_unsubscribes() -> void:
	var holder := _build_holder()
	var item_holder := ItemHolder.new()
	item_holder.name = "ItemHolder"
	holder.add_child(item_holder)
	var stats: Stats = holder.get_node("Stats")
	var em: EventManager = holder.get_node("EventManager")
	var scene: PackedScene = load(LIFE_LEACH_SCENE)
	var life_leach_item := ItemBuilder.make_effect_item("Life Leach", "", scene)
	item_holder.add_item(life_leach_item)
	assert_bool(stats.stats.has("lifeleach")).is_true()
	item_holder.remove_item(life_leach_item)
	assert_bool(stats.stats.has("lifeleach")).is_false()
	# emitting after removal must not error (listener unsubscribed, node gone)
	var hit := DamageContext.new()
	hit.final_amount = 50.0
	em.emit_event("on_hit", {"damage_context": hit})
	holder.free()


func test_modifier_without_provided_stat_adds_nothing() -> void:
	var holder := _build_holder()
	var stats: Stats = holder.get_node("Stats")
	var before_keys: Array = stats.stats.keys()
	var modifier := BaseModifier.new()
	modifier.provided_stat = ""
	holder.add_child(modifier)
	modifier._cache_holder(holder.get_node("EventManager"))
	modifier.add_stack(true)
	assert_int(stats.stats.keys().size()).is_equal(before_keys.size())
	holder.free()


func test_factory_candidates_include_dynamic_stats() -> void:
	var test_scene = load("res://test/SceneWithItemFactory.tscn").instantiate()
	add_child(test_scene)
	var item_factory: ItemFactory = test_scene.get_node("ItemFactory")
	var candidates: Array = item_factory._candidate_stat_names()
	assert_bool("lifeleach" in candidates).is_true()
	assert_bool("armor" in candidates).is_true()
	test_scene.free()