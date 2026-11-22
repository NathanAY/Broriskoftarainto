# The ECO budget from docs/systems/balance.md §1.3: an economy item bought in the
# loop-1 shop must pay back 2-3x its price, in loop-1 coins, by the loop-3 shop.
#
# Every number about the items is read from game_config.json and run through the
# real code (`Wallet.payday`, `BossSpawner.bounty_for`), so a rebalance moves the
# figures without rotting the suite. The one thing pinned is the INCOME PROFILE
# below: it is a measurement of play, not a balance value, and is re-measured
# (and updated here and in balance.md §1.3) when enemy pacing changes.
class_name EconomyRoiBudgetTest
extends GdUnitTestSuite

## Measured 2026-11-22, Multitasker, loops 1-3 (docs/systems/balance.md §1.3).
## Index 0 is unused so the arrays read by loop number.
const KILLS := [0, 45, 70, 62]
## Coins spent in each loop's shop.
const SPENT := [0, 42, 55, 93]
## Coins carried into each loop's shop from the previous one.
const CARRIED := [0, 0, 8, 33]
## Seconds of wave per loop (`StageManager.stage_duration`).
const WAVE_SECONDS := 20.0

## §1.3: coin-returning items pay back 2-3x.
const ROI_MIN := 2.0
const ROI_MAX := 3.0
## A free reroll is worth the better offer it finds, which coins saved do not
## capture, so shop-quality items are held to a lower floor (§1.3).
const SHOP_QUALITY_ROI_MIN := 1.5


func _economy(key: String, fallback: Variant) -> float:
	return float(GameConfig.section("economy").get(key, fallback))


func _roll(stat_name: String) -> float:
	return float(GameConfig.section("item_generation").get("stat_overrides", {}).get(stat_name, {}).get("roll", 1.0))


func _modifier(scene_name: String, key: String) -> float:
	return float(GameConfig.section("economy_modifiers").get(scene_name, {}).get(key, 0.0))


## What a coin earned in `loop` is worth in loop-1 coins: prices grow each loop.
func _deflator(loop: int) -> float:
	return 1.0 + _economy("item_price_growth_per_loop", 0.0) * (loop - 1)


func _price(type: String) -> float:
	return float(GameConfig.section("economy").get("type_prices", {}).get(type, 1))


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


func _assert_band(label: String, roi: float, low: float = ROI_MIN) -> void:
	assert_float(roi).override_failure_message(
		"%s pays back %.2fx its price by the loop-3 shop (band %.1f..%.1f)" % [label, roi, low, ROI_MAX]
	).is_between(low, ROI_MAX)


# --- Stat items (price `stat`) ----------------------------------------------------


func test_stock_investment_item_is_in_band() -> void:
	var character := _build_character()
	character.stats.set_base_stat("stock_investment", _roll("stock_investment"))
	var returned := 0.0
	for loop in [2, 3]:
		returned += float(Wallet.payday(character, loop).get("dividend", 0.0)) / _deflator(loop)
		character.stats.set_base_stat("money", 0.0)
	_assert_band("stock_investment", returned / _price("stat"))


func test_coin_gain_item_is_in_band() -> void:
	var returned := 0.0
	for loop in [2, 3]:
		var coins: float = KILLS[loop] * _economy("coins_per_kill", 1) + BossSpawner.bounty_for(loop, false)
		returned += _roll("coin_gain") * coins / _deflator(loop)
	_assert_band("coin_gain", returned / _price("stat"))


func test_interest_rate_item_is_in_band() -> void:
	var character := _build_character()
	character.stats.set_base_stat("interest_rate", _roll("interest_rate"))
	var returned := 0.0
	for loop in [2, 3]:
		character.income_by_loop.clear()
		character.stats.set_base_stat("money", CARRIED[loop])
		returned += float(Wallet.payday(character, loop).get("interest", 0.0)) / _deflator(loop)
	_assert_band("interest_rate", returned / _price("stat"))


func test_shop_discount_item_is_in_band() -> void:
	var returned := 0.0
	for loop in [2, 3]:
		returned += _roll("shop_discount") * SPENT[loop] / _deflator(loop)
	_assert_band("shop_discount", returned / _price("stat"))


# --- Effect items (price `effect`) ------------------------------------------------


func test_bounty_mark_is_in_band() -> void:
	var marks := floorf(WAVE_SECONDS / _modifier("BountyMarkModifier", "interval"))
	var returned := 0.0
	for loop in [2, 3]:
		var bounty: float = _modifier("BountyMarkModifier", "coins_base") + _modifier("BountyMarkModifier", "coins_per_loop") * (loop - 1)
		returned += marks * bounty / _deflator(loop)
	_assert_band("BountyMarkModifier", returned / _price("effect"))


## One free reroll in the loop-1 shop it is bought in, and one in each later shop.
func test_regular_customer_is_in_the_shop_quality_band() -> void:
	var economy := GameConfig.section("economy")
	var returned := 0.0
	for loop in [1, 2, 3]:
		var reroll: float = float(economy.get("reroll_base_cost", 1)) + float(economy.get("reroll_loop_step", 2)) * (loop - 1)
		returned += reroll / _deflator(loop)
	_assert_band("RegularCustomerModifier", returned / _price("effect"), SHOP_QUALITY_ROI_MIN)


## The cash-out modifiers are not coin items: they are budgeted on the core
## +15% rule (balance.md §1), at their cap, for the first stack.
func test_cash_out_modifiers_stay_under_the_item_cap() -> void:
	for scene_name in ["GildedEdgeModifier", "MarketRallyModifier"]:
		assert_float(_modifier(scene_name, "cap")).override_failure_message(scene_name).is_less_equal(0.15)
