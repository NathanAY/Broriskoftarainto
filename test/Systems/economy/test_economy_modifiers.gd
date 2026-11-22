# Phase 2 of the economy build plan (docs/plans/economy-build-direction.md):
# the economy modifiers. Every expectation is derived from the modifier's block
# in the `economy_modifiers` config, never from a literal.
class_name EconomyModifiersTest
extends GdUnitTestSuite

const DIR := "res://src/Systems/Items/modifiers/"

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
	var health := Health.new()
	health.name = "Health"
	character.add_child(health)
	health.max_health = 50.0
	health.current_health = 50.0
	return character


func _attach(character: Character, scene_name: String, stack_count: int = 1) -> BaseModifier:
	var modifier := BaseModifier.attach(load(DIR + scene_name + ".tscn"), character, character.event_manager)
	for i in range(stack_count - 1):
		modifier.add_stack(true)
	return modifier


func _cfg(scene_name: String, key: String) -> float:
	return float(GameConfig.section("economy_modifiers").get(scene_name, {}).get(key, 0.0))


# --- Gilded Edge: coins held -> damage -----------------------------------------


func test_gilded_edge_grants_damage_per_coin_held() -> void:
	var character := _build_character()
	_attach(character, "GildedEdgeModifier")
	var per_coin := _cfg("GildedEdgeModifier", "per_unit")
	var coins := 0.5 * _cfg("GildedEdgeModifier", "cap") / per_coin  # half way to the cap

	Wallet.earn(character, coins, "kill")

	assert_float(character.stats.get_stat("damage")).is_equal_approx(1.0 + coins * per_coin, 0.0001)


func test_gilded_edge_follows_spending_down() -> void:
	var character := _build_character()
	_attach(character, "GildedEdgeModifier")
	Wallet.earn(character, 20.0, "kill")
	Wallet.spend(character, 20.0, "buy")
	assert_float(character.stats.get_stat("damage")).is_equal(1.0)


func test_gilded_edge_cap_grows_with_extra_stacks() -> void:
	var character := _build_character()
	_attach(character, "GildedEdgeModifier", 2)
	Wallet.earn(character, 100000.0, "kill")
	var cap := _cfg("GildedEdgeModifier", "cap") + _cfg("GildedEdgeModifier", "cap_per_extra_stack")
	assert_float(character.stats.get_stat("damage")).is_equal_approx(1.0 + cap, 0.0001)


func test_gilded_edge_takes_its_damage_back_on_detach() -> void:
	var character := _build_character()
	var modifier := _attach(character, "GildedEdgeModifier")
	Wallet.earn(character, 20.0, "kill")
	modifier.detach()
	assert_float(character.stats.get_stat("damage")).is_equal(1.0)


# --- Market Rally: stock -> attack speed ---------------------------------------


func test_market_rally_grants_attack_speed_per_stock() -> void:
	var character := _build_character()
	_attach(character, "MarketRallyModifier")
	var per_stock := _cfg("MarketRallyModifier", "per_unit")
	var stock := 0.5 * _cfg("MarketRallyModifier", "cap") / per_stock

	character.stats.set_base_stat("stock_investment", stock)

	assert_float(character.stats.get_stat("attack_speed")).is_equal_approx(1.0 + stock * per_stock, 0.0001)


func test_market_rally_is_capped() -> void:
	var character := _build_character()
	_attach(character, "MarketRallyModifier")
	character.stats.set_base_stat("stock_investment", 100000.0)
	assert_float(character.stats.get_stat("attack_speed")).is_equal_approx(1.0 + _cfg("MarketRallyModifier", "cap"), 0.0001)


# --- Insurance Policy: coins -> survive a lethal hit ---------------------------


func _lethal_hit(character: Character) -> DamageContext:
	var ctx := DamageContext.new()
	ctx.target = character
	ctx.final_amount = 9999.0
	character.event_manager.emit_event("before_take_damage", {"damage_context": ctx})
	return ctx


func _premium() -> float:
	return _cfg("InsurancePolicyModifier", "premium_base")  # loop 1 outside a game


func test_insurance_turns_a_lethal_hit_into_a_survivable_one() -> void:
	var character := _build_character()
	_attach(character, "InsurancePolicyModifier")
	Wallet.earn(character, _premium() + 5.0, "kill")
	var health: Health = character.get_node("Health")

	var ctx := _lethal_hit(character)

	assert_float(health.current_health - ctx.final_amount).is_greater(0.0)
	assert_float(Wallet.balance(character)).is_equal(5.0)


func test_insurance_pays_out_once_per_loop() -> void:
	var character := _build_character()
	_attach(character, "InsurancePolicyModifier")
	Wallet.earn(character, _premium() * 3.0, "kill")
	_lethal_hit(character)

	assert_float(_lethal_hit(character).final_amount).is_equal(9999.0)

	character.event_manager.emit_event("on_shop_enter", {"loop": 1})
	assert_float(_lethal_hit(character).final_amount).is_less(9999.0)


func test_insurance_does_nothing_without_the_premium() -> void:
	var character := _build_character()
	_attach(character, "InsurancePolicyModifier")
	Wallet.earn(character, _premium() - 1.0, "kill")
	assert_float(_lethal_hit(character).final_amount).is_equal(9999.0)
	assert_float(Wallet.balance(character)).is_equal(_premium() - 1.0)


func test_insurance_ignores_a_hit_that_is_not_lethal() -> void:
	var character := _build_character()
	_attach(character, "InsurancePolicyModifier")
	Wallet.earn(character, _premium(), "kill")
	var ctx := DamageContext.new()
	ctx.final_amount = 5.0
	character.event_manager.emit_event("before_take_damage", {"damage_context": ctx})
	assert_float(ctx.final_amount).is_equal(5.0)
	assert_float(Wallet.balance(character)).is_equal(_premium())


# --- Bounty Mark: kill the marked enemy for coins ------------------------------


func _kill(character: Character, target: Node) -> void:
	var ctx := DamageContext.new()
	ctx.target = target
	character.event_manager.emit_event("on_kill", {"damage_context": ctx})


func test_killing_a_marked_enemy_pays_the_bounty() -> void:
	var character := _build_character()
	var modifier := _attach(character, "BountyMarkModifier")
	var enemy: Node2D = auto_free(Node2D.new())
	modifier.mark(enemy)

	_kill(character, enemy)

	assert_float(Wallet.balance(character)).is_equal(_cfg("BountyMarkModifier", "coins_base"))


func test_an_unmarked_kill_pays_no_bounty() -> void:
	var character := _build_character()
	_attach(character, "BountyMarkModifier")
	_kill(character, auto_free(Node2D.new()))
	assert_float(Wallet.balance(character)).is_equal(0.0)


func test_bounty_mark_picks_a_living_enemy() -> void:
	var character := _build_character()
	var modifier := _attach(character, "BountyMarkModifier")
	var enemy: Node2D = auto_free(Node2D.new())
	add_child(enemy)
	enemy.add_to_group("enemies")

	modifier.mark_random_enemy()

	assert_bool(BountyMarkModifier.is_marked(enemy)).is_true()


# --- Regular Customer: free rerolls --------------------------------------------


func test_regular_customer_makes_the_first_reroll_free() -> void:
	var character := _build_character()
	character.add_child(_named(ItemHolder.new(), "ItemHolder"))
	character.add_child(_named(WeaponHolder.new(), "WeaponHolder"))
	_attach(character, "RegularCustomerModifier")
	var shop: ShopMenu = auto_free(load("res://src/Scenes/menu/ShopMenu.tscn").instantiate())
	add_child(shop)
	var factory: ItemFactory = auto_free(load("res://src/Systems/Items/ItemFactory.tscn").instantiate())
	add_child(factory)
	shop.item_factory = factory
	shop.character = character
	GlobalGameState.current_character = character
	Wallet.earn(character, 100.0, "kill")
	shop.show_menu()
	shop.load_items([])
	var paid_cost: int = Wallet.config().get("reroll_base_cost", 1)

	assert_int(shop.reroll_cost()).is_equal(0)
	shop._on_reroll_pressed()

	assert_float(Wallet.balance(character)).is_equal(100.0)
	assert_int(shop.reroll_cost()).is_equal(paid_cost)
	get_tree().paused = false


func _named(node: Node, node_name: String) -> Node:
	node.name = node_name
	return node


# --- Fire Sale: selling buys stock ---------------------------------------------


func test_fire_sale_turns_a_sale_into_stock() -> void:
	var character := _build_character()
	_attach(character, "FireSaleModifier")
	character.event_manager.emit_event("on_sell", {"resource": null, "price": 4})
	assert_float(character.stats.get_stat("stock_investment")).is_equal_approx(
		4.0 * _cfg("FireSaleModifier", "stock_per_coin"), 0.0001)


# --- Tax Collector: a cost ------------------------------------------------------


func test_tax_collector_takes_a_share_after_payday() -> void:
	var character := _build_character()
	var modifier := _attach(character, "TaxCollectorModifier")
	Wallet.earn(character, 50.0, "kill")
	var rate := _cfg("TaxCollectorModifier", "tax_rate")

	Wallet.payday(character, 1)

	assert_float(Wallet.balance(character)).is_equal(50.0 - floorf(50.0 * rate))
	assert_int(modifier.effect_kind).is_equal(BaseModifier.EffectKind.COST)


# --- Every new modifier ----------------------------------------------------------


func test_every_economy_modifier_has_a_config_block() -> void:
	var block: Dictionary = GameConfig.section("economy_modifiers")
	for scene_name in ["GildedEdgeModifier", "MarketRallyModifier", "InsurancePolicyModifier",
			"BountyMarkModifier", "RegularCustomerModifier", "FireSaleModifier", "TaxCollectorModifier"]:
		assert_bool(ResourceLoader.exists(DIR + scene_name + ".tscn")).override_failure_message(scene_name).is_true()
		assert_bool(block.has(scene_name)).override_failure_message(scene_name).is_true()
