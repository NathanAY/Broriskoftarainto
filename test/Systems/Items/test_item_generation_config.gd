# GdUnit TestSuite for the item-generation knobs in `res://game_config.json`:
# per-modifier drop weights, and how often an already generated item is
# re-offered. The suite sets the knobs on the factory itself, so it pins the
# mechanic and not whatever numbers the config file holds today.
class_name ItemGenerationConfigTest
extends GdUnitTestSuite

const FACTORY_SCENE := "res://src/Systems/Items/ItemFactory.tscn"
const SEED: int = 20260930
const BATCH: int = 400
const FLAT_DRAIN := "FlatLifeDrainModifier"
const PERCENT_DRAIN := "PercentLifeDrainModifier"


func _factory() -> ItemFactory:
	var factory: ItemFactory = load(FACTORY_SCENE).instantiate()
	add_child(factory)
	factory.rng.seed = SEED
	return factory


func _scene_key(scene: PackedScene) -> String:
	return scene.resource_path.get_file().get_basename()


## How many times each cost scene comes up over a batch of weighted picks.
func _cost_pick_counts(factory: ItemFactory) -> Dictionary:
	var counts := {}
	for i in range(BATCH):
		var key := _scene_key(factory._pick_weighted_scene(factory._cost_effect_scenes()))
		counts[key] = counts.get(key, 0) + 1
	return counts


## How many of `BATCH` draws generated a new item rather than re-offering one.
func _new_item_count(factory: ItemFactory) -> int:
	for i in range(BATCH):
		factory.get_item_from_pool_or_generate()
	return factory.drop_pool.size()


# --- the config file -------------------------------------------------------------

func test_config_file_parses_and_feeds_the_factory() -> void:
	var block := GameConfig.section("item_generation")
	assert_bool(block.is_empty()).override_failure_message(
		"game_config.json is missing, invalid, or has no item_generation block").is_false()
	var factory := _factory()
	assert_float(factory.negative_modifier_chance).is_equal(float(block["negative_modifier_chance"]))
	assert_float(factory.repeat_item_chance_scale).is_equal(float(block["repeat_item_chance_scale"]))
	assert_dict(factory.modifier_weights).is_equal(block["modifier_weights"])
	collect_orphan_node_details()


func test_every_configured_weight_names_a_real_modifier_scene() -> void:
	# A typo in the file would otherwise be a weight that silently does nothing.
	var factory := _factory()
	var known := []
	for scene in factory.effect_scenes:
		known.append(_scene_key(scene))
	for key in factory.modifier_weights:
		assert_bool(key in known).override_failure_message(
			"game_config.json weights '%s', which is not a scene in the modifiers folder" % key).is_true()
	collect_orphan_node_details()


# --- modifier weights ------------------------------------------------------------

func test_a_zero_weight_modifier_is_never_picked() -> void:
	var factory := _factory()
	factory.modifier_weights = {PERCENT_DRAIN: 0.0}
	var counts := _cost_pick_counts(factory)
	assert_int(counts.get(PERCENT_DRAIN, 0)).is_equal(0)
	assert_int(counts.get(FLAT_DRAIN, 0)).is_equal(BATCH)
	collect_orphan_node_details()


func test_a_lower_weight_is_picked_less_often() -> void:
	var factory := _factory()
	factory.modifier_weights = {PERCENT_DRAIN: 0.25}
	var counts := _cost_pick_counts(factory)
	# Present, but clearly behind the scene left at the default weight of 1.
	assert_int(counts.get(PERCENT_DRAIN, 0)).is_greater(0)
	assert_int(counts.get(PERCENT_DRAIN, 0) * 2).is_less(counts.get(FLAT_DRAIN, 0))
	collect_orphan_node_details()


func test_all_zero_weights_fall_back_to_a_uniform_pick() -> void:
	var factory := _factory()
	factory.modifier_weights = {PERCENT_DRAIN: 0.0, FLAT_DRAIN: 0.0}
	var counts := _cost_pick_counts(factory)
	assert_int(counts.get(PERCENT_DRAIN, 0)).is_greater(0)
	assert_int(counts.get(FLAT_DRAIN, 0)).is_greater(0)
	collect_orphan_node_details()


func test_generated_items_respect_the_weight() -> void:
	# End to end: the weight reaches the items, not just the helper.
	var factory := _factory()
	factory.negative_modifier_chance = 1.0
	factory.modifier_weights = {PERCENT_DRAIN: 0.0}
	for type in ["stat", "effect", "buff", "debuff"]:
		for i in range(50):
			var item: Item = factory.get_item_by_type(type)
			for scene in item.effect_scene:
				assert_str(_scene_key(scene)).override_failure_message(
					"a '%s' item rolled the zero-weight drain" % type).is_not_equal(PERCENT_DRAIN)
	collect_orphan_node_details()


# --- repeat items ----------------------------------------------------------------

func test_scale_zero_generates_a_new_item_every_time() -> void:
	var factory := _factory()
	factory.repeat_item_chance_scale = 0.0
	assert_int(_new_item_count(factory)).is_equal(BATCH)
	collect_orphan_node_details()


func test_a_smaller_scale_generates_more_new_items() -> void:
	var full := _factory()
	full.repeat_item_chance_scale = 1.0
	var quarter := _factory()
	quarter.repeat_item_chance_scale = 0.25
	var new_at_full := _new_item_count(full)
	var new_at_quarter := _new_item_count(quarter)
	assert_int(new_at_quarter).is_greater(new_at_full)
	# At a quarter the repeat chance can never pass 25%, so new items dominate.
	assert_int(new_at_quarter * 2).is_greater(BATCH)
	collect_orphan_node_details()
