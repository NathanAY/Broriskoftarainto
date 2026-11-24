# Phase 1 of the economy build plan (docs/plans/economy-build-direction.md):
# the five economy stats and the payday that runs when the shop opens.
#
# No balance number is pinned: every expectation is derived from the `economy`
# config the code is supposed to read.
class_name EconomyStatsTest
extends GdUnitTestSuite

const STAT_ITEM := "res://src/Resources/items/PlusDamageItem.tres"
const WEAPON := "res://src/Resources/weapons/Pistol.tres"
const SPAWNER_MODIFIER := "res://src/Scripts/spawner_modifier.gd"

var _events: Array = []


func before_test() -> void:
	_events = []


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


func _record(payload: Dictionary) -> void:
	_events.append(payload)


func _economy(key: String, fallback: Variant) -> float:
	return float(GameConfig.section("economy").get(key, fallback))


## Money left over from the previous shop. Seeded straight into the stat, so the
## wallet does not count it as this stage's income.
func _carry_over(character: Character, amount: float) -> void:
	character.stats.set_base_stat("money", amount)


# --- Stock investment ---------------------------------------------------------


func test_payday_pays_stock_then_grows_it() -> void:
	var character := _build_character()
	character.stats.set_base_stat("stock_investment", 20.0)

	var breakdown := Wallet.payday(character, 1)

	var growth := _economy("stock_growth", 0.1)
	assert_float(breakdown.get("dividend", 0.0)).is_equal(20.0)
	assert_float(Wallet.balance(character)).is_equal(20.0)
	assert_float(character.stats.get_stat("stock_investment")).is_equal_approx(20.0 * (1.0 + growth), 0.0001)


## Stock that came from items still grows, and the growth lands on the base, so
## it survives selling the item.
func test_stock_from_items_grows_into_the_base() -> void:
	var character := _build_character()
	var item_mod := {"stock_investment": {"flat": 10.0}}
	character.stats.add_modifier(item_mod)

	Wallet.payday(character, 1)
	character.stats.remove_modifier(item_mod)

	assert_float(character.stats.get_stat("stock_investment")).is_equal_approx(10.0 * _economy("stock_growth", 0.1), 0.0001)


func test_dividend_pays_whole_coins_and_keeps_the_fraction() -> void:
	var character := _build_character()
	character.stats.set_base_stat("stock_investment", 2.5)

	var breakdown := Wallet.payday(character, 1)

	assert_float(breakdown.get("dividend", 0.0)).is_equal(2.0)
	assert_float(character.stats.get_stat("stock_investment")).is_greater(2.5)


func test_stock_stops_growing_at_its_cap() -> void:
	var character := _build_character()
	var cap := _economy("stock_investment_cap", 100.0)
	character.stats.set_base_stat("stock_investment", cap)

	Wallet.payday(character, 1)

	assert_float(character.stats.get_stat("stock_investment")).is_equal(cap)


func test_negative_stock_pays_nothing() -> void:
	var character := _build_character()
	character.stats.set_base_stat("stock_investment", -3.0)

	Wallet.payday(character, 1)

	assert_float(Wallet.balance(character)).is_equal(0.0)
	assert_float(character.stats.get_stat("stock_investment")).is_equal(-3.0)


# --- Interest -----------------------------------------------------------------


## Interest rewards money *carried over* from the last shop, not this stage's
## kills, so the same rate cannot double as an income multiplier.
func test_interest_is_paid_on_carried_over_money_only() -> void:
	var character := _build_character()
	var rate := 0.1
	character.stats.set_base_stat("interest_rate", rate)
	_carry_over(character, 30.0)
	Wallet.earn(character, 50.0, "kill")

	var breakdown := Wallet.payday(character, 1)

	assert_float(breakdown.get("interest", 0.0)).is_equal(float(mini(floori(rate * 30.0), int(_economy("interest_cap", 10)))))


func test_interest_is_capped_per_payday() -> void:
	var character := _build_character()
	character.stats.set_base_stat("interest_rate", _economy("interest_rate_cap", 0.3))
	_carry_over(character, 100000.0)

	var breakdown := Wallet.payday(character, 1)

	assert_float(breakdown.get("interest", 0.0)).is_equal(_economy("interest_cap", 10))


func test_interest_rate_is_capped() -> void:
	var character := _build_character()
	character.stats.set_base_stat("interest_rate", 50.0)
	assert_float(Wallet.stat(character, "interest_rate")).is_equal(_economy("interest_rate_cap", 0.3))


# --- Payday bookkeeping -------------------------------------------------------


func test_payday_emits_breakdown_and_tallies_income() -> void:
	var character := _build_character()
	character.stats.set_base_stat("stock_investment", 5.0)
	character.event_manager.subscribe("on_payday", _record)

	Wallet.payday(character, 1)

	assert_int(_events.size()).is_equal(1)
	assert_int(_events[0]["stage"]).is_equal(1)
	assert_float(_events[0]["breakdown"].get("dividend", 0.0)).is_equal(5.0)
	assert_float(Wallet.income_for_stage(character, 1).get("dividend", 0.0)).is_equal(5.0)


func test_payday_runs_once_per_shop_visit() -> void:
	var character := _build_character()
	character.add_child(_named(ItemHolder.new(), "ItemHolder"))
	character.add_child(_named(WeaponHolder.new(), "WeaponHolder"))
	character.stats.set_base_stat("stock_investment", 5.0)
	character.event_manager.subscribe("on_payday", _record)
	var shop: ShopMenu = auto_free(load("res://src/Scenes/menu/ShopMenu.tscn").instantiate())
	add_child(shop)
	shop.character = character
	GlobalGameState.current_character = character

	shop.show_menu()
	shop.show_menu()

	assert_int(_events.size()).is_equal(1)
	assert_str(shop.money_label.text).contains("+5")
	get_tree().paused = false


func _named(node: Node, node_name: String) -> Node:
	node.name = node_name
	return node


# --- Coin gain ----------------------------------------------------------------


func test_coin_gain_multiplies_kill_coins() -> void:
	var character := _build_character()
	character.stats.set_base_stat("coin_gain", 0.5)
	var spawner_modifier: Node = auto_free(load(SPAWNER_MODIFIER).new())
	spawner_modifier.character = character

	spawner_modifier.award_kill()

	assert_float(Wallet.balance(character)).is_equal_approx(_economy("coins_per_kill", 1) * 1.5, 0.0001)


func test_coin_gain_never_makes_a_kill_cost_money() -> void:
	var character := _build_character()
	character.stats.set_base_stat("coin_gain", -5.0)
	assert_float(Wallet.coins_for(character, 1.0)).is_equal(0.0)


# --- Discount and resale ------------------------------------------------------


func test_discount_lowers_the_price_but_never_below_one() -> void:
	var analyzer: ItemPriceAnalyzer = auto_free(ItemPriceAnalyzer.new())
	var weapon: BaseWeapon = load(WEAPON)
	var full := analyzer.get_price(weapon, 1)
	assert_int(analyzer.get_price(weapon, 1, 0.4)).is_equal(maxi(1, roundi(full * 0.6)))
	assert_int(analyzer.get_price(load(STAT_ITEM), 1, 0.99)).is_equal(1)


func test_shop_discount_is_capped() -> void:
	var character := _build_character()
	character.stats.set_base_stat("shop_discount", 5.0)
	assert_float(Wallet.stat(character, "shop_discount")).is_equal(_economy("shop_discount_cap", 0.4))


func test_resale_raises_the_sell_ratio_up_to_its_cap() -> void:
	var character := _build_character()
	var base_ratio := _economy("sell_ratio", 0.5)
	character.stats.set_base_stat("resale_value", 0.05)
	assert_float(Wallet.sell_ratio(character)).is_equal_approx(base_ratio + 0.05, 0.0001)
	character.stats.set_base_stat("resale_value", 5.0)
	assert_float(Wallet.sell_ratio(character)).is_equal_approx(base_ratio + _economy("resale_value_cap", 0.4), 0.0001)


## A discounted weapon must never sell back for more than it cost.
func test_selling_a_discounted_buy_never_profits() -> void:
	var analyzer: ItemPriceAnalyzer = auto_free(ItemPriceAnalyzer.new())
	var weapon: BaseWeapon = load(WEAPON)
	var discount := _economy("shop_discount_cap", 0.4)
	var ratio := _economy("sell_ratio", 0.5) + _economy("resale_value_cap", 0.4)
	for stage in [1, 2, 3, 6]:
		assert_int(analyzer.get_sell_price(weapon, ratio, stage, discount)).is_less_equal(
			analyzer.get_price(weapon, stage, discount))


# --- Generation and display ---------------------------------------------------


func test_economy_stats_never_roll_as_buffs_or_debuffs() -> void:
	var factory: ItemFactory = auto_free(load("res://src/Systems/Items/ItemFactory.tscn").instantiate())
	add_child(factory)
	factory.rng.seed = 7
	for i in range(200):
		for type in ["buff", "debuff"]:
			var item: Item = factory.get_item_by_type(type)
			var payload: Node = item.effect_scene[0].instantiate()
			for stat_name in payload.modifiers:
				assert_bool(stat_name in Wallet.ECONOMY_STATS).override_failure_message(
					"%s rolled a temporary %s" % [type, stat_name]).is_false()
			payload.free()


## The stats start at 0, so a rolled line takes its amount from the `roll`
## override instead of the generic "1 when the base is 0".
func test_zero_base_economy_stat_rolls_its_configured_amount() -> void:
	var factory: ItemFactory = auto_free(load("res://src/Systems/Items/ItemFactory.tscn").instantiate())
	add_child(factory)
	var overrides: Dictionary = GameConfig.section("item_generation").get("stat_overrides", {})
	for stat_name in Wallet.ECONOMY_STATS:
		var expected := float(overrides.get(stat_name, {}).get("roll", 1.0))
		assert_float(float(factory._generate_stat_modifiers(stat_name, 0.0)["flat"])).is_equal(expected)


func test_zero_economy_stats_are_hidden_from_stat_lists() -> void:
	var character := _build_character()
	var names: Array = character.stats.display_stat_names()
	for stat_name in Wallet.ECONOMY_STATS:
		assert_bool(names.has(stat_name)).is_false()
	character.stats.set_base_stat("coin_gain", 0.03)
	assert_bool(character.stats.display_stat_names().has("coin_gain")).is_true()
