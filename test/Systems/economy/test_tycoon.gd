# Phase 3 of the economy build plan (docs/plans/economy-build-direction.md):
# the Tycoon and his Credit Line. Expectations come from the
# `economy_modifiers.CreditLineModifier` config block, never from literals.
class_name TycoonTest
extends GdUnitTestSuite

const CREDIT_LINE := "res://src/Systems/Items/modifiers/CreditLineModifier.tscn"
const TAX := "res://src/Systems/Items/modifiers/TaxCollectorModifier.tscn"
const TYCOON := "res://src/Assets/character/tycoon/Tycoon.tres"


func _build_character() -> Character:
	var character: Character = auto_free(Character.new())
	var event_manager := EventManager.new()
	event_manager.name = "EventManager"
	character.add_child(event_manager)
	var stats := Stats.new()
	stats.name = "Stats"
	stats.event_manager = event_manager
	character.add_child(stats)
	return character


func _with_credit() -> Character:
	var character := _build_character()
	BaseModifier.attach(load(CREDIT_LINE), character, character.event_manager)
	return character


func _cfg(key: String) -> float:
	return float(GameConfig.section("economy_modifiers").get("CreditLineModifier", {}).get(key, 0.0))


# --- Spending into debt ---------------------------------------------------------


func test_credit_line_lets_the_holder_spend_into_debt() -> void:
	var character := _with_credit()
	var limit := _cfg("credit_limit")

	assert_bool(Wallet.spend(character, limit, "buy")).is_true()
	assert_float(Wallet.balance(character)).is_equal(-limit)


func test_debt_stops_at_the_credit_limit() -> void:
	var character := _with_credit()
	assert_bool(Wallet.spend(character, _cfg("credit_limit") + 1.0, "buy")).is_false()
	assert_float(Wallet.balance(character)).is_equal(0.0)


func test_without_credit_nobody_goes_into_debt() -> void:
	var character := _build_character()
	assert_bool(Wallet.can_afford(character, 1.0)).is_false()


func test_credit_limit_is_a_stat_items_can_raise() -> void:
	var character := _with_credit()
	character.stats.add_modifier({"credit_limit": {"flat": 5.0}})
	assert_float(Wallet.credit(character)).is_equal(_cfg("credit_limit") + 5.0)


# --- Being in debt --------------------------------------------------------------


func test_debt_costs_damage_until_it_is_repaid() -> void:
	var character := _with_credit()
	var base_damage := character.stats.get_stat("damage")

	Wallet.spend(character, 5.0, "buy")
	assert_float(character.stats.get_condition("in_debt")).is_equal(1.0)
	assert_float(character.stats.get_stat("damage")).is_equal_approx(
		base_damage * (1.0 - _cfg("debt_damage_penalty")), 0.0001)

	Wallet.earn(character, 5.0, "kill")
	assert_float(character.stats.get_condition("in_debt")).is_equal(0.0)
	assert_float(character.stats.get_stat("damage")).is_equal(base_damage)


func test_debt_grows_when_the_shop_opens() -> void:
	var character := _with_credit()
	Wallet.spend(character, 10.0, "buy")

	character.event_manager.emit_event("on_shop_enter", {"loop": 1})

	assert_float(Wallet.balance(character)).is_equal(-10.0 - ceilf(10.0 * _cfg("debt_interest")))


func test_no_debt_means_no_debt_interest() -> void:
	var character := _with_credit()
	Wallet.earn(character, 10.0, "kill")
	character.event_manager.emit_event("on_shop_enter", {"loop": 1})
	assert_float(Wallet.balance(character)).is_equal(10.0)


func test_tax_collector_does_not_tax_debt() -> void:
	var character := _with_credit()
	BaseModifier.attach(load(TAX), character, character.event_manager)
	Wallet.spend(character, 10.0, "buy")
	Wallet.payday(character, 1)
	assert_float(Wallet.balance(character)).is_equal(-10.0)


func test_credit_line_is_never_a_generated_item() -> void:
	var factory: ItemFactory = auto_free(load("res://src/Systems/Items/ItemFactory.tscn").instantiate())
	add_child(factory)
	factory.rng.seed = 11
	for i in range(300):
		var item: Item = factory.get_item_by_type("effect")
		for scene in item.effect_scene:
			assert_str(scene.resource_path).is_not_equal(CREDIT_LINE)


# --- The character --------------------------------------------------------------


## The kit's identity, not its numbers: he invests (starting stock), fights for
## less (negative coin gain) and borrows (Credit Line).
func test_tycoon_kit_is_an_economy_kit() -> void:
	var data: CharacterData = load(TYCOON)
	assert_float(float(data.base_stats.get("stock_investment", 0.0))).is_greater(0.0)
	assert_float(float(data.base_stats.get("coin_gain", 0.0))).is_less(0.0)
	var paths := data.modifiers.map(func(entry): return entry.resource_path if entry is PackedScene else "")
	assert_array(paths).contains([CREDIT_LINE])
	assert_int(data.starting_weapons.size()).is_equal(1)
	assert_object(data.eyes).is_not_null()
	assert_object(data.mouth).is_not_null()
