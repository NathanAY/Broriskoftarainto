# GdUnit TestSuite for ItemFactory's positive / negative halves.
#
# Every generated item is a gift and a curse. The curse used to be *only* a
# negated stat; now it can also be a real harmful modifier (a life drain),
# appended as a second entry of `Item.effect_scene`. Two rules make that safe:
#
# - the positive half only ever rolls a BENEFIT scene and the negative half only
#   a COST scene, so a shop can never offer "Grants special effect: Life Drain";
# - the two pools are derived from `BaseModifier.effect_kind`, so adding a
#   harmful modifier to the folder is all it takes to widen the pool.
#
# The chance is a hardcoded const, so every test pins `rng.seed` and draws a
# batch: a fixed seed makes the batch reproducible, so "both branches appear" is
# a deterministic assertion rather than a flaky one.
class_name ItemFactoryPolarityTest
extends GdUnitTestSuite

const FACTORY_SCENE := "res://src/Systems/Items/ItemFactory.tscn"
const SEED: int = 20260930
## How many items to draw per batch. Sized so the 0.35 chance fires many times
## while the seed keeps the exact count fixed.
const BATCH: int = 200


func _factory() -> ItemFactory:
	var factory: ItemFactory = load(FACTORY_SCENE).instantiate()
	add_child(factory)
	factory.rng.seed = SEED
	return factory


func _kind_of(scene: PackedScene) -> int:
	if scene == null:
		return -1
	var instance: Node = scene.instantiate()
	if instance == null:
		return -1
	var kind := -1
	for p in instance.get_property_list():
		if p.name == "effect_kind":
			kind = int(instance.get("effect_kind"))
			break
	instance.free()
	return kind


func _batch(factory: ItemFactory, type: String) -> Array[Item]:
	var items: Array[Item] = []
	for i in range(BATCH):
		var item: Item = factory.get_item_by_type(type)
		if item != null:
			items.append(item)
	return items


func _has_negative_stat(item: Item) -> bool:
	for stat_name in item.modifiers:
		var mod = item.modifiers[stat_name]
		if typeof(mod) != TYPE_DICTIONARY:
			continue
		for mod_type in mod:
			if float(mod[mod_type]) < 0.0:
				return true
	return false


func _cost_scenes(item: Item) -> Array:
	var found := []
	if item.effect_scene == null:
		return found
	for scene in item.effect_scene:
		if _kind_of(scene) == BaseModifier.EffectKind.COST:
			found.append(scene)
	return found


# --- the two pools -------------------------------------------------------------

func test_cost_pool_holds_only_cost_scenes() -> void:
	var factory := _factory()
	assert_bool(factory._cost_effect_scenes().size() > 0).is_true()
	for scene in factory._cost_effect_scenes():
		assert_int(_kind_of(scene)).override_failure_message(
			"%s is in the cost pool but is not a COST" % scene.resource_path).is_equal(
			BaseModifier.EffectKind.COST)
	collect_orphan_node_details()


func test_benefit_pool_holds_no_cost_scenes() -> void:
	var factory := _factory()
	assert_bool(factory._benefit_effect_scenes().size() > 0).is_true()
	for scene in factory._benefit_effect_scenes():
		assert_int(_kind_of(scene)).override_failure_message(
			"%s is a COST and must not be offered as an upside" % scene.resource_path).is_equal(
			BaseModifier.EffectKind.BENEFIT)
	collect_orphan_node_details()


func test_the_two_pools_partition_every_scene() -> void:
	# A scene in both pools could be picked for either half; a scene in neither
	# would be unreachable. The folders are small enough to compare by count.
	var factory := _factory()
	assert_int(factory._benefit_effect_scenes().size() + factory._cost_effect_scenes().size()).is_equal(
		factory.effect_scenes.size())
	collect_orphan_node_details()


# --- the roll ------------------------------------------------------------------

func test_effect_items_never_offer_a_cost_as_their_upside() -> void:
	var factory := _factory()
	for item in _batch(factory, "effect"):
		if item.effect_scene == null or item.effect_scene.is_empty():
			continue
		assert_int(_kind_of(item.effect_scene[0])).override_failure_message(
			"'%s' offers '%s' as its positive half" % [item.name, item.effect_scene[0].resource_path]).is_equal(
			BaseModifier.EffectKind.BENEFIT)
	collect_orphan_node_details()


func test_a_negative_modifier_does_show_up_sometimes() -> void:
	# Proves the branch is reachable, not dead code. With the seed pinned this is
	# a fixed outcome rather than a coin flip.
	var factory := _factory()
	var with_cost := 0
	for item in _batch(factory, "effect"):
		if _cost_scenes(item).size() > 0:
			with_cost += 1
	assert_int(with_cost).override_failure_message(
		"no effect item ever rolled a harmful modifier").is_greater(0)
	collect_orphan_node_details()


func test_a_negative_stat_is_used_when_no_negative_modifier_is_rolled() -> void:
	# The two halves are alternatives, not a stack: exactly one of them carries
	# the curse so an item never gets a double penalty from the same roll.
	var factory := _factory()
	for item in _batch(factory, "effect"):
		var has_cost := _cost_scenes(item).size() > 0
		assert_bool(has_cost != _has_negative_stat(item)).override_failure_message(
			"'%s' has cost_scene=%s and negative_stat=%s; expected exactly one" % [
				item.name, has_cost, _has_negative_stat(item)]).is_true()
	collect_orphan_node_details()


func test_a_negative_modifier_lands_after_the_positive_one() -> void:
	# Index order matters: Item.effect_scene_condition is a parallel array, and
	# the positive half must stay at [0] so the item still reads as a gift first.
	var factory := _factory()
	for item in _batch(factory, "effect"):
		if item.effect_scene == null or item.effect_scene.size() < 2:
			continue
		assert_int(_kind_of(item.effect_scene[item.effect_scene.size() - 1])).is_equal(
			BaseModifier.EffectKind.COST)
	collect_orphan_node_details()


# --- all four generators -------------------------------------------------------

func test_every_generator_can_produce_a_negative_modifier() -> void:
	var factory := _factory()
	for type in ["stat", "effect", "buff", "debuff"]:
		var with_cost := 0
		for item in _batch(factory, type):
			if _cost_scenes(item).size() > 0:
				with_cost += 1
		assert_int(with_cost).override_failure_message(
			"'%s' items never rolled a harmful modifier" % type).is_greater(0)
	collect_orphan_node_details()


func test_every_generated_item_still_has_a_downside() -> void:
	var factory := _factory()
	for type in ["stat", "effect", "buff", "debuff"]:
		for item in _batch(factory, type):
			assert_bool(_cost_scenes(item).size() > 0 or _has_negative_stat(item)).override_failure_message(
				"'%s' (%s) has no downside at all" % [item.name, type]).is_true()
	collect_orphan_node_details()


func test_a_stat_item_with_a_cost_scene_keeps_its_positive_stat() -> void:
	# The awkward shape: a stat item whose only effect scene is a drawback. The
	# positive stat has to survive, and stay a positive stat on the card.
	var factory := _factory()
	var checked := 0
	for item in _batch(factory, "stat"):
		if _cost_scenes(item).size() == 0:
			continue
		assert_bool(item.modifiers.size() > 0).override_failure_message(
			"'%s' carries a drain but no stat at all" % item.name).is_true()
		var has_positive := false
		for stat_name in item.modifiers:
			var mod = item.modifiers[stat_name]
			if typeof(mod) == TYPE_DICTIONARY:
				for mod_type in mod:
					if float(mod[mod_type]) > 0.0:
						has_positive = true
		assert_bool(has_positive).override_failure_message(
			"'%s' carries a drain but no positive stat to trade against it" % item.name).is_true()
		checked += 1
	assert_int(checked).override_failure_message("no stat item ever rolled a drain").is_greater(0)
	collect_orphan_node_details()


func test_a_stat_item_with_a_cost_scene_renders_both_halves() -> void:
	var factory := _factory()
	for item in _batch(factory, "stat"):
		if _cost_scenes(item).size() == 0:
			continue
		var rows: Array = ItemTooltip.card_rows(item)
		var effect_rows := 0
		var stat_rows := 0
		for row in rows:
			var typed: ItemCardRow = row
			if typed.kind == ItemCardRow.Kind.EFFECT:
				effect_rows += 1
			elif typed.kind == ItemCardRow.Kind.STAT:
				stat_rows += 1
		assert_int(effect_rows).override_failure_message(
			"'%s' hides its drain on the card" % item.name).is_equal(1)
		assert_bool(stat_rows > 0).override_failure_message(
			"'%s' loses its stats from the card" % item.name).is_true()
	collect_orphan_node_details()


func test_a_buff_item_with_a_drain_names_the_drain() -> void:
	# A buff item's scene 0 is the packed payload; a drain the factory appended
	# sits after it. Both the card and the flat tooltip have to show it, or the
	# player reads a buff as a free upgrade.
	var factory := _factory()
	var checked := 0
	for item in _batch(factory, "buff"):
		if _cost_scenes(item).size() == 0:
			continue
		assert_bool(item.effect_scene.size() > 1).override_failure_message(
			"'%s' reports a drain but carries only one scene" % item.name).is_true()
		var payload_row_skipped := false
		var drain_seen := false
		for row in ItemTooltip.card_rows(item):
			var typed: ItemCardRow = row
			if typed.kind == ItemCardRow.Kind.EFFECT and typed.tone == ItemCardRow.Tone.NEGATIVE:
				drain_seen = true
		assert_bool(drain_seen).override_failure_message(
			"'%s' hides its drain on the card" % item.name).is_true()
		for line in ItemTooltip.tooltip_lines(item):
			if line.begins_with("effect:"):
				payload_row_skipped = true
		assert_bool(payload_row_skipped).override_failure_message(
			"'%s' hides its drain in the hover tooltip" % item.name).is_true()
		checked += 1
	assert_int(checked).override_failure_message("no buff item ever rolled a drain").is_greater(0)
	collect_orphan_node_details()


func test_a_buff_item_with_a_drain_keeps_its_payload_green() -> void:
	# The payload must not be dragged into the cost tone by the drain sitting
	# beside it: the player still gets the buff.
	var factory := _factory()
	for item in _batch(factory, "buff"):
		if _cost_scenes(item).size() == 0:
			continue
		var positives := 0
		for row in ItemTooltip.card_rows(item):
			var typed: ItemCardRow = row
			if typed.kind == ItemCardRow.Kind.STAT and typed.tone == ItemCardRow.Tone.POSITIVE:
				positives += 1
		assert_int(positives).override_failure_message(
			"'%s' lost its green buff payload" % item.name).is_greater(0)
	collect_orphan_node_details()


func test_buff_and_debuff_still_route_through_their_payload_rows() -> void:
	# Buff/debuff items carry a packed payload scene, not a BaseModifier, so they
	# keep their own route: the payload renders as forced-POSITIVE (buff) or
	# forced-NEGATIVE (debuff) STAT rows. `ItemCardRow.Kind.BUFF` / `.DEBUFF` are
	# only ever used as the tone selector inside `_append_buff_debuff_rows` - no
	# row is ever tagged with them - so the tone is what has to be asserted.
	var factory := _factory()
	for type in ["buff", "debuff"]:
		var checked := 0
		for item in _batch(factory, type):
			var want := ItemCardRow.Tone.POSITIVE if type == "buff" else ItemCardRow.Tone.NEGATIVE
			var matched := 0
			for row in ItemTooltip.card_rows(item):
				var typed: ItemCardRow = row
				if typed.kind == ItemCardRow.Kind.STAT and typed.tone == want:
					matched += 1
			assert_int(matched).override_failure_message(
				"'%s' (%s) has no payload row in the %s tone" % [item.name, type, type]).is_greater(0)
			checked += 1
		assert_int(checked).is_greater(0)
	collect_orphan_node_details()


func test_a_debuff_item_stays_all_negative() -> void:
	# The mirror guard: a debuff's payload AND its curse are both losses, so a
	# refactor that started deriving payload tone from the value could not make
	# one of them read as a gain.
	var factory := _factory()
	for item in _batch(factory, "debuff"):
		for row in ItemTooltip.card_rows(item):
			var typed: ItemCardRow = row
			if typed.kind == ItemCardRow.Kind.STAT:
				assert_int(typed.tone).override_failure_message(
					"'%s' has a positive stat row" % item.name).is_equal(ItemCardRow.Tone.NEGATIVE)
	collect_orphan_node_details()
