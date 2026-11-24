# GdUnit TestSuite for generated item rarity (`ItemFactory.roll_rarity` /
# `apply_rarity`). Every expectation is derived from `Item.rarity_value`, so the
# suite pins the mechanic and not the numbers in `game_config.json`.
class_name ItemRarityTest
extends GdUnitTestSuite

const FACTORY_SCENE := "res://src/Systems/Items/ItemFactory.tscn"
const BUFF_SCENE := "res://src/Systems/Items/Buffs/buff.tscn"
const KNOCKBACK_SCENE := "res://src/Systems/Items/modifiers/KnockbackModifier.tscn"
const SEED: int = 20261122
const BATCH: int = 2000
const LEGENDARY := BaseWeapon.Rarity.LEGENDARY


func _factory() -> ItemFactory:
	var factory: ItemFactory = load(FACTORY_SCENE).instantiate()
	add_child(factory)
	factory.rng.seed = SEED
	return factory


func _counts(factory: ItemFactory, stage: int) -> Array[int]:
	var counts: Array[int] = [0, 0, 0, 0, 0]
	for i in range(BATCH):
		counts[factory.roll_rarity(stage)] += 1
	return counts


## A hand-made item with one gain and one loss, so extra lines are the only new keys.
func _base_item() -> Item:
	return ItemBuilder.make_stat_item("Test", "", {
		"damage": {"flat": 1.0},
		"armor": {"flat": -1.0},
	})


func _count_lines(item: Item, gains: bool) -> int:
	var count := 0
	for stat_name in item.modifiers:
		var flat := float(item.modifiers[stat_name]["flat"])
		if (flat > 0.0) == gains:
			count += 1
	return count


func test_config_block_has_one_value_per_rarity() -> void:
	var block := GameConfig.section("item_rarity")
	assert_bool(block.is_empty()).override_failure_message(
		"game_config.json has no item_rarity block").is_false()
	for key in Item.RARITY_DEFAULTS:
		assert_int((block[key] as Array).size()).override_failure_message(
			"item_rarity.%s needs one value per rarity" % key).is_equal(LEGENDARY + 1)


func test_every_tier_can_roll_and_common_leads() -> void:
	var counts := _counts(_factory(), 1)
	for tier in range(LEGENDARY + 1):
		assert_int(counts[tier]).override_failure_message("tier %d never rolled" % tier).is_greater(0)
	assert_int(counts.max()).is_equal(counts[BaseWeapon.Rarity.COMMON])


func test_later_stages_roll_higher_rarity_more_often() -> void:
	var first := _counts(_factory(), 1)
	var later := _counts(_factory(), 4)
	assert_int(later[LEGENDARY]).is_greater(first[LEGENDARY])
	assert_int(later[BaseWeapon.Rarity.COMMON]).is_less(first[BaseWeapon.Rarity.COMMON])


func test_rarity_scales_gains_by_positive_and_losses_by_negative_multiplier() -> void:
	var factory := _factory()
	for tier in range(LEGENDARY + 1):
		var item := _base_item()
		factory.apply_rarity(item, tier as BaseWeapon.Rarity)
		assert_int(item.rarity).is_equal(tier)
		assert_float(float(item.modifiers["damage"]["flat"])).is_equal_approx(
			snappedf(Item.rarity_value("positive_multipliers", tier), 0.01), 0.001)
		assert_float(float(item.modifiers["armor"]["flat"])).is_equal_approx(
			snappedf(-Item.rarity_value("negative_multipliers", tier), 0.01), 0.001)
	# The design: a rarity's gain grows faster than its loss.
	assert_float(Item.rarity_value("positive_multipliers", LEGENDARY)).is_greater(
		Item.rarity_value("negative_multipliers", LEGENDARY))


func test_buff_payload_scales_with_rarity() -> void:
	var factory := _factory()
	var item := ItemBuilder.make_buff_item("Buff", "", "attack_speed", {"flat": 0.5}, load(BUFF_SCENE))
	factory.apply_rarity(item, LEGENDARY)
	var payload := ItemTooltip.peek_packed_modifiers(item.effect_scene[0])
	assert_float(float(payload["attack_speed"]["flat"])).is_equal_approx(
		snappedf(0.5 * Item.rarity_value("positive_multipliers", LEGENDARY), 0.01), 0.001)


func test_higher_rarity_gets_more_gain_lines_and_fewer_loss_lines() -> void:
	var factory := _factory()
	var common_gains := 0
	var common_losses := 0
	var legendary_gains := 0
	var legendary_losses := 0
	for i in range(300):
		var common := _base_item()
		factory.apply_rarity(common, BaseWeapon.Rarity.COMMON)
		common_gains += _count_lines(common, true)
		common_losses += _count_lines(common, false)
		var legendary := _base_item()
		factory.apply_rarity(legendary, LEGENDARY)
		legendary_gains += _count_lines(legendary, true)
		legendary_losses += _count_lines(legendary, false)
		# A common item never gets an extra gain line; a legendary at most one per tier step.
		assert_int(_count_lines(common, true)).is_equal(1)
		assert_int(_count_lines(legendary, true)).is_less_equal(1 + LEGENDARY)
		assert_int(_count_lines(legendary, false)).is_less_equal(2)
	assert_int(legendary_gains).is_greater(common_gains)
	assert_int(legendary_losses).is_less(common_losses)


func test_generated_items_carry_a_rolled_rarity() -> void:
	var factory := _factory()
	var seen := {}
	for i in range(300):
		seen[factory.generate_random_item().rarity] = true
	assert_int(seen.size()).is_greater(1)


func test_price_scales_with_rarity() -> void:
	var analyzer := ItemPriceAnalyzer.new()
	var common := ItemBuilder.make_effect_item("Knock", "", load(KNOCKBACK_SCENE))
	var legendary := ItemBuilder.make_effect_item("Knock", "", load(KNOCKBACK_SCENE))
	legendary.rarity = LEGENDARY
	var common_price := analyzer.get_price(common)
	assert_int(analyzer.get_price(legendary)).is_equal(
		roundi(common_price * Item.rarity_value("positive_multipliers", LEGENDARY)))
	assert_int(analyzer.get_price(legendary)).is_greater(common_price)
	analyzer.free()


func test_extra_gain_line_on_an_effect_item_renders_as_a_gain() -> void:
	var item := ItemBuilder.make_effect_item("Knock", "", load(KNOCKBACK_SCENE),
		{"damage": {"flat": 0.5}, "armor": {"flat": -1.0}})
	var tones := {}
	for row in ItemTooltip.card_rows(item):
		if row.kind == ItemCardRow.Kind.STAT:
			tones[row.stat_name] = row.tone
	assert_int(tones["damage"]).is_equal(ItemCardRow.Tone.POSITIVE)
	assert_int(tones["armor"]).is_equal(ItemCardRow.Tone.NEGATIVE)
	var lines := ItemTooltip.tooltip_lines(item)
	assert_that(lines).contains("damage flat: 0.5")
	assert_that(lines).contains("tradeoff: armor flat: -1.0")
