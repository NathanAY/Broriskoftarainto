# GdUnit TestSuite for the harmful-modifier marking contract: a modifier declares
# itself a COST through `BaseModifier.effect_kind`, and the item card renders that
# effect line red instead of the default heading gold.
class_name NegativeModifierMarkingTest
extends GdUnitTestSuite

const BASE := preload("res://src/Systems/Items/modifiers/base_modifier.gd")
const FLAT_REGEN_SCENE := "res://src/Systems/Items/modifiers/FlatRegenModifier.tscn"
const PERCENT_REGEN_SCENE := "res://src/Systems/Items/modifiers/PercentRegenModifier.tscn"
const FLAT_DRAIN_SCENE := "res://src/Systems/Items/modifiers/FlatLifeDrainModifier.tscn"
const PERCENT_DRAIN_SCENE := "res://src/Systems/Items/modifiers/PercentLifeDrainModifier.tscn"
const KNOCKBACK_SCENE := "res://src/Systems/Items/modifiers/KnockbackModifier.tscn"
const DRAIN_ITEM := "res://src/Resources/items/LifeDrain.tres"
const REGEN_ITEM := "res://src/Resources/items/RegenPassive.tres"


func _effect_row(resource_path: String) -> ItemCardRow:
	var rows: Array = ItemTooltip.card_rows(load(resource_path))
	for row in rows:
		var typed: ItemCardRow = row
		if typed.kind == ItemCardRow.Kind.EFFECT:
			return typed
	return null


func test_base_modifier_defaults_to_benefit() -> void:
	# Every one of the 23 existing modifiers must keep rendering as before, so
	# the new property has to default to the harmless kind.
	var modifier = BASE.new()
	assert_int(modifier.effect_kind).is_equal(BaseModifier.EffectKind.BENEFIT)
	modifier.free()


func test_benefit_and_cost_are_distinct_kinds() -> void:
	# The card maps these onto ItemCardRow.Tone by name, not by casting, so the
	# two enums are deliberately free to use different integers.
	assert_int(BaseModifier.EffectKind.COST).is_not_equal(int(ItemCardRow.Tone.NEGATIVE))


func test_life_drain_scenes_declare_themselves_a_cost() -> void:
	for path in [FLAT_DRAIN_SCENE, PERCENT_DRAIN_SCENE]:
		var instance: Node = load(path).instantiate()
		assert_int(instance.get("effect_kind")).override_failure_message(
			"%s should declare effect_kind = COST" % path).is_equal(BaseModifier.EffectKind.COST)
		instance.free()


func test_positive_regen_scenes_stay_a_benefit() -> void:
	for path in ["res://src/Systems/Items/modifiers/FlatRegenModifier.tscn",
			"res://src/Systems/Items/modifiers/PercentRegenModifier.tscn"]:
		var instance: Node = load(path).instantiate()
		assert_int(instance.get("effect_kind")).override_failure_message(
			"%s should stay a BENEFIT" % path).is_equal(BaseModifier.EffectKind.BENEFIT)
		instance.free()


func test_drain_item_effect_row_is_toned_negative() -> void:
	var row := _effect_row(DRAIN_ITEM)
	assert_that(row).is_not_null()
	assert_int(row.tone).is_equal(ItemCardRow.Tone.NEGATIVE)
	# The tone lives on the row, not baked into the text, so the line still reads
	# as prose and the colour is a pure presentation concern.
	assert_str(row.text).contains("Life Drain")


func test_benefit_item_effect_row_stays_neutral() -> void:
	var row := _effect_row(REGEN_ITEM)
	assert_that(row).is_not_null()
	assert_int(row.tone).is_equal(ItemCardRow.Tone.NEUTRAL)


func test_drain_item_effect_line_renders_red() -> void:
	var item: Resource = load(DRAIN_ITEM)
	var bbcode: String = ItemDisplayPanel.build_bbcode(ItemTooltip.card_rows(item), item)
	assert_str(bbcode).contains(ItemDisplayPanel.COLOR_NEGATIVE.to_html(false))
	assert_str(bbcode).not_contains(ItemDisplayPanel.COLOR_HEADING.to_html(false))


func test_benefit_item_effect_line_keeps_heading_gold() -> void:
	var item: Resource = load(REGEN_ITEM)
	var bbcode: String = ItemDisplayPanel.build_bbcode(ItemTooltip.card_rows(item), item)
	# Regression guard: the neutral effect line must not drift off gold.
	assert_str(bbcode).contains(ItemDisplayPanel.COLOR_HEADING.to_html(false))
	assert_str(bbcode).not_contains(ItemDisplayPanel.COLOR_NEGATIVE.to_html(false))


func test_resolve_effect_display_reports_the_effect_kind() -> void:
	var display: Dictionary = ItemTooltip.resolve_effect_display(load(FLAT_DRAIN_SCENE))
	assert_int(int(display.get("effect_kind", -1))).is_equal(BaseModifier.EffectKind.COST)

	var regen: Dictionary = ItemTooltip.resolve_effect_display(
		load("res://src/Systems/Items/modifiers/FlatRegenModifier.tscn"))
	assert_int(int(regen.get("effect_kind", -1))).is_equal(BaseModifier.EffectKind.BENEFIT)


func test_factory_caches_the_effect_kind_onto_the_item() -> void:
	# Generated items resolve the display once at build time and cache it as
	# metadata, so the factory has to persist the kind too or a generated drain
	# would silently fall back to gold.
	var item := Item.new()
	item.name = "Generated Drain"
	item.effect_scene = [load(FLAT_DRAIN_SCENE)]
	var factory := ItemFactory.new()
	factory._store_effect_display(item, [load(FLAT_DRAIN_SCENE)])

	assert_int(int(ItemTooltip.resolve_effect_display_for_item(item, 0).get("effect_kind", -1))).is_equal(
		BaseModifier.EffectKind.COST)
	factory.free()


func test_cached_item_metadata_drives_the_red_row() -> void:
	# The cached path (what the shop actually reads) has to tint the row, not just
	# the reflective one.
	var item := Item.new()
	item.name = "Generated Drain"
	item.effect_scene = [load(FLAT_DRAIN_SCENE)]
	var factory := ItemFactory.new()
	factory._store_effect_display(item, [load(FLAT_DRAIN_SCENE)])
	factory.free()

	var rows: Array = ItemTooltip.card_rows(item)
	for row in rows:
		var typed: ItemCardRow = row
		if typed.kind == ItemCardRow.Kind.EFFECT:
			assert_int(typed.tone).is_equal(ItemCardRow.Tone.NEGATIVE)
			return
	fail("no EFFECT row on the cached display")


# --- multi-effect items: every scene gets its own toned row -------------------

func _effect_rows(resource_path: String) -> Array:
	return _effect_rows_for(load(resource_path))


## Every EFFECT row of an item, in `effect_scene` order.
func _effect_rows_for(item: Item) -> Array:
	var found := []
	for row in ItemTooltip.card_rows(item):
		var typed: ItemCardRow = row
		if typed.kind == ItemCardRow.Kind.EFFECT:
			found.append(typed)
	return found


func _polarity_item(scenes: Array[PackedScene], modifiers: Dictionary = {}) -> Item:
	var item := Item.new()
	item.name = "Cursed Charm"
	item.description = "A gift and a curse."
	item.effect_scene = scenes
	item.modifiers = modifiers
	return item


func test_card_renders_one_effect_row_per_scene() -> void:
	var item := _polarity_item([load(FLAT_REGEN_SCENE), load(FLAT_DRAIN_SCENE)])
	var rows := _effect_rows_for(item)
	# The old code only ever read effect_scene[0], which hid the downside.
	assert_int(rows.size()).is_equal(2)
	assert_str(rows[0].text).contains("Flat Regen")
	assert_str(rows[1].text).contains("Life Drain")


func test_each_effect_row_is_toned_by_its_own_kind() -> void:
	var item := _polarity_item([load(FLAT_REGEN_SCENE), load(FLAT_DRAIN_SCENE)])
	var rows := _effect_rows_for(item)
	assert_int(rows[0].tone).is_equal(ItemCardRow.Tone.NEUTRAL)
	assert_int(rows[1].tone).is_equal(ItemCardRow.Tone.NEGATIVE)


func test_multi_effect_bbcode_carries_both_gold_and_red() -> void:
	var item := _polarity_item([load(FLAT_REGEN_SCENE), load(FLAT_DRAIN_SCENE)])
	var bbcode: String = ItemDisplayPanel.build_bbcode(ItemTooltip.card_rows(item), item)
	assert_str(bbcode).contains(ItemDisplayPanel.COLOR_HEADING.to_html(false))
	assert_str(bbcode).contains(ItemDisplayPanel.COLOR_NEGATIVE.to_html(false))


func test_two_cost_scenes_on_one_item_are_both_red() -> void:
	var item := _polarity_item([load(FLAT_DRAIN_SCENE), load(PERCENT_DRAIN_SCENE)])
	var rows := _effect_rows_for(item)
	assert_int(rows.size()).is_equal(2)
	assert_int(rows[0].tone).is_equal(ItemCardRow.Tone.NEGATIVE)
	assert_int(rows[1].tone).is_equal(ItemCardRow.Tone.NEGATIVE)


func test_an_effect_item_keeps_its_stat_modifiers_as_tradeoffs() -> void:
	# The item's positive half is the effect, so every stat on it is a cost and
	# stays forced red even though a "tradeoff" can read as a gain.
	var item := _polarity_item([load(KNOCKBACK_SCENE), load(FLAT_DRAIN_SCENE)], {"armor": {"flat": 2.0}})
	for row in ItemTooltip.card_rows(item):
		var typed: ItemCardRow = row
		if typed.kind == ItemCardRow.Kind.STAT:
			assert_int(typed.tone).override_failure_message(
				"a positive stat on an effect item is still a tradeoff").is_equal(ItemCardRow.Tone.NEGATIVE)


func test_a_stat_item_carrying_only_a_cost_keeps_its_positive_stat_green() -> void:
	# The mirror case: no BENEFIT scene, so the positive stat is a real gain and
	# must keep the tone its value implies rather than being forced red.
	var item := _polarity_item([load(FLAT_DRAIN_SCENE)],
		{"damage": {"flat": 5.0}, "armor": {"flat": -2.0}})
	var tones := {}
	for row in ItemTooltip.card_rows(item):
		var typed: ItemCardRow = row
		if typed.kind == ItemCardRow.Kind.STAT:
			tones[typed.label] = typed.tone
	assert_int(int(tones.get("Damage", -1))).is_equal(ItemCardRow.Tone.POSITIVE)
	assert_int(int(tones.get("Armor", -1))).is_equal(ItemCardRow.Tone.NEGATIVE)


func test_a_plain_stat_item_is_unchanged() -> void:
	# No scenes at all: the pre-existing per-value rule must still hold.
	var item := _polarity_item([], {"damage": {"flat": 5.0}, "armor": {"flat": -2.0}})
	var tones := {}
	for row in ItemTooltip.card_rows(item):
		var typed: ItemCardRow = row
		if typed.kind == ItemCardRow.Kind.STAT:
			tones[typed.label] = typed.tone
	assert_int(int(tones.get("Damage", -1))).is_equal(ItemCardRow.Tone.POSITIVE)
	assert_int(int(tones.get("Armor", -1))).is_equal(ItemCardRow.Tone.NEGATIVE)


func test_multi_effect_flat_tooltip_lines_include_every_scene() -> void:
	var item := _polarity_item([load(FLAT_REGEN_SCENE), load(FLAT_DRAIN_SCENE)])
	var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
	var effect_lines := 0
	for line in lines:
		if line.begins_with("effect:"):
			effect_lines += 1
	assert_int(effect_lines).is_equal(2)


func test_factory_caches_a_display_entry_per_scene() -> void:
	# The cache is aligned with effect_scene by index, the same way
	# effect_scene_condition already is, so both halves resolve statically.
	var scenes: Array[PackedScene] = [load(FLAT_REGEN_SCENE), load(FLAT_DRAIN_SCENE)]
	var item := _polarity_item(scenes)
	var factory := ItemFactory.new()
	factory._store_effect_display(item, scenes)
	factory.free()

	var cached: Array = ItemTooltip.resolve_effect_displays_for_item(item)
	assert_int(cached.size()).is_equal(2)
	assert_int(int(ItemTooltip.resolve_effect_display_for_item(item, 0).get("effect_kind", -1))).is_equal(
		BaseModifier.EffectKind.BENEFIT)
	assert_int(int(ItemTooltip.resolve_effect_display_for_item(item, 1).get("effect_kind", -1))).is_equal(
		BaseModifier.EffectKind.COST)


func test_cached_multi_scene_item_tints_every_row() -> void:
	# The steady-state path (what the shop reads) has to tone both halves, not
	# just the one the old single-entry cache knew about.
	var scenes: Array[PackedScene] = [load(FLAT_REGEN_SCENE), load(FLAT_DRAIN_SCENE)]
	var item := _polarity_item(scenes)
	var factory := ItemFactory.new()
	factory._store_effect_display(item, scenes)
	factory.free()

	var rows := _effect_rows_for(item)
	assert_int(rows.size()).is_equal(2)
	assert_int(rows[0].tone).is_equal(ItemCardRow.Tone.NEUTRAL)
	assert_int(rows[1].tone).is_equal(ItemCardRow.Tone.NEGATIVE)
