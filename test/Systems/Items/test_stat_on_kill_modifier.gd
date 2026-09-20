# GdUnit TestSuite for StatOnKillModifier (replaces LifeOnKillModifier)
class_name StatOnKillModifierTest
extends GdUnitTestSuite

const BASE_SCENE := "res://src/Systems/Items/Modifiers/StatOnKillModifier.tscn"


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
	add_child(holder)
	return holder


func _attach_modifier(holder: Node, scene_path: String) -> Node:
	var scene: PackedScene = load(scene_path)
	var modifier: Node = scene.instantiate()
	holder.add_child(modifier)
	modifier.attachEventManager(holder.get_node("EventManager"))
	modifier.add_stack(true)
	return modifier


func test_on_kill_event_is_accepted_by_contract() -> void:
	var holder := _build_holder()
	var em: EventManager = holder.get_node("EventManager")
	var res := em.emit_event("on_kill", {"damage_context": {}})
	assert_that(res.ok).is_true()
	holder.free()


func test_stat_on_kill_increases_health_by_default() -> void:
	var holder := _build_holder()
	var stats: Stats = holder.get_node("Stats")
	var before: float = stats.stats.get("health")
	var modifier := _attach_modifier(holder, BASE_SCENE)
	assert_str(str(modifier.get("trigger_event"))).is_equal("on_kill")
	assert_str(str(modifier.get("target_stat"))).is_equal("health")
	holder.get_node("EventManager").emit_event("on_kill", {"damage_context": {}})
	assert_float(float(stats.stats.get("health"))).is_equal(before + float(modifier.get("add_amount")))
	holder.free()


func test_stat_on_kill_configured_stat_damage() -> void:
	var holder := _build_holder()
	var stats: Stats = holder.get_node("Stats")
	var scene: PackedScene = load(BASE_SCENE)
	var inst: Node = scene.instantiate()
	inst.set("target_stat", "damage")
	inst.set("add_amount", 2.0)
	var configured: PackedScene = ItemBuilder.pack_instance(inst)
	inst.free()
	var modifier: Node = configured.instantiate()
	holder.add_child(modifier)
	modifier.attachEventManager(holder.get_node("EventManager"))
	modifier.add_stack(true)
	var before: float = float(stats.stats.get("damage"))
	holder.get_node("EventManager").emit_event("on_kill", {"damage_context": {}})
	assert_float(float(stats.stats.get("damage"))).is_equal(before + 2.0)
	holder.free()


func test_stat_on_kill_does_not_trigger_on_hit() -> void:
	var holder := _build_holder()
	var stats: Stats = holder.get_node("Stats")
	var before: float = float(stats.stats.get("health"))
	_attach_modifier(holder, BASE_SCENE)
	holder.get_node("EventManager").emit_event("on_hit", {"damage_context": {}})
	assert_float(float(stats.stats.get("health"))).is_equal(before)
	holder.free()


func test_factory_configures_random_stat_on_kill() -> void:
	var factory: ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
	add_child(factory)
	var base_scene: PackedScene = load(BASE_SCENE)
	var configured: PackedScene = factory._configure_dynamic_modifier(base_scene)
	assert_object(configured).is_not_null()
	var inst: Node = configured.instantiate()
	var target_stat := str(inst.get("target_stat"))
	assert_bool(target_stat in factory.stats.stats.keys()).is_true()
	assert_bool(float(inst.get("add_amount")) > 0.0).is_true()
	inst.free()
	collect_orphan_node_details()


func test_stat_on_kill_randomize_owns_stat_roll() -> void:
	# The modifier itself owns randomization: no factory needed.
	var factory: ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
	add_child(factory)
	var modifier: StatOnKillModifier = StatOnKillModifier.new()
	add_child(modifier)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var mutated: bool = modifier.randomize_for_generation({"rng": rng, "stats": factory.stats.stats})
	assert_bool(mutated).is_true()
	assert_bool(str(modifier.target_stat) in factory.stats.stats.keys()).is_true()
	assert_bool(modifier.add_amount > 0.0).is_true()
	assert_str(modifier.get_generation_suffix()).is_equal(" (%s)" % modifier.target_stat)
	modifier.free()
	collect_orphan_node_details()


func test_stat_on_kill_randomize_empty_stats_returns_false() -> void:
	var modifier: StatOnKillModifier = StatOnKillModifier.new()
	add_child(modifier)
	var rng := RandomNumberGenerator.new()
	assert_bool(modifier.randomize_for_generation({"rng": rng, "stats": {}})).is_false()
	assert_str(modifier.target_stat).is_equal("health")
	modifier.free()
	collect_orphan_node_details()


func test_heal_on_event_randomize_owns_trigger_roll() -> void:
	var modifier: HealOnEventModifier = HealOnEventModifier.new()
	add_child(modifier)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	assert_bool(modifier.randomize_for_generation({"rng": rng, "stats": {}})).is_true()
	var table: Dictionary = modifier.possible_trigger_event
	assert_bool(str(modifier.trigger_event) in table.keys()).is_true()
	assert_that(modifier.default_heal).is_equal(int(table[modifier.trigger_event]["default_heal"]))
	modifier.free()
	collect_orphan_node_details()


func test_factory_passes_through_scenes_without_hook() -> void:
	var factory: ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
	add_child(factory)
	# ChainMod has no randomize_for_generation: returned untouched.
	var plain_scene: PackedScene = load("res://src/Systems/Items/Modifiers/ChainMod.tscn")
	assert_that(factory._configure_dynamic_modifier(plain_scene)).is_same(plain_scene)
	collect_orphan_node_details()
