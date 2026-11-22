# Phase 0 of the economy build plan (docs/plans/economy-build-direction.md):
# every coin goes through `Wallet`, money changes are observable as events, and
# the economy numbers come from the `economy` block of game_config.json.
#
# Balance numbers are never pinned here. Each expectation is derived from the
# config value the code is supposed to read, so a rebalance keeps the suite green.
class_name EconomyTest
extends GdUnitTestSuite

const BOSS_SPAWNER := "res://src/Systems/BossSpawner.tscn"
const SPAWNER_MODIFIER := "res://src/Scripts/spawner_modifier.gd"
const STAT_ITEM := "res://src/Resources/items/PlusDamageItem.tres"
const WEAPON := "res://src/Resources/weapons/Pistol.tres"

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


func _economy(key: String, fallback: Variant) -> Variant:
	return GameConfig.section("economy").get(key, fallback)


# --- Wallet ------------------------------------------------------------------


func test_earn_adds_money_and_reports_the_source() -> void:
	var character := _build_character()
	character.event_manager.subscribe("on_money_changed", _record)

	Wallet.earn(character, 3.0, "kill")

	assert_float(Wallet.balance(character)).is_equal(3.0)
	assert_int(_events.size()).is_equal(1)
	assert_float(_events[0]["old"]).is_equal(0.0)
	assert_float(_events[0]["new"]).is_equal(3.0)
	assert_str(_events[0]["source"]).is_equal("kill")


func test_spend_deducts_when_affordable() -> void:
	var character := _build_character()
	Wallet.earn(character, 5.0, "kill")
	character.event_manager.subscribe("on_money_changed", _record)

	assert_bool(Wallet.spend(character, 2.0, "buy")).is_true()

	assert_float(Wallet.balance(character)).is_equal(3.0)
	assert_int(_events.size()).is_equal(1)
	assert_str(_events[0]["source"]).is_equal("buy")


func test_spend_refuses_and_changes_nothing_when_short() -> void:
	var character := _build_character()
	Wallet.earn(character, 1.0, "kill")
	character.event_manager.subscribe("on_money_changed", _record)

	assert_bool(Wallet.spend(character, 2.0, "buy")).is_false()

	assert_float(Wallet.balance(character)).is_equal(1.0)
	assert_array(_events).is_empty()


## The tally is what the measurement in Phase 0 reads, so it must split income
## by source and ignore spending.
func test_income_is_tallied_by_source() -> void:
	var character := _build_character()
	Wallet.earn(character, 1.0, "kill")
	Wallet.earn(character, 1.0, "kill")
	Wallet.earn(character, 4.0, "boss")
	Wallet.spend(character, 3.0, "buy")

	var tally: Dictionary = Wallet.income_for_loop(character, 1)
	assert_float(tally.get("kill", 0.0)).is_equal(2.0)
	assert_float(tally.get("boss", 0.0)).is_equal(4.0)
	assert_bool(tally.has("buy")).is_false()


# --- Kill reward and boss bounty ----------------------------------------------


func test_a_kill_pays_the_configured_coins() -> void:
	var character := _build_character()
	var spawner_modifier: Node = auto_free(load(SPAWNER_MODIFIER).new())
	spawner_modifier.character = character

	spawner_modifier.award_kill()

	assert_float(Wallet.balance(character)).is_equal(float(_economy("coins_per_kill", 1)))


func test_boss_bounty_grows_with_the_loop() -> void:
	var base := float(_economy("boss_coins_base", 0))
	var per_loop := float(_economy("boss_coins_per_loop", 0))
	assert_int(BossSpawner.bounty_for(1, false)).is_equal(roundi(base))
	assert_int(BossSpawner.bounty_for(3, false)).is_equal(roundi(base + per_loop * 2))


func test_final_boss_pays_nothing() -> void:
	assert_int(BossSpawner.bounty_for(3, true)).is_equal(0)


## The real path: a spawned loop boss dying pays its bounty to the character.
func test_dying_loop_boss_pays_its_bounty() -> void:
	var root: Node = auto_free(Node.new())
	add_child(root)
	var nodes := Node.new()
	nodes.name = "Nodes"
	root.add_child(nodes)
	var enemies := Node.new()
	enemies.name = "Enemies"
	nodes.add_child(enemies)
	var stage := Node.new()
	stage.name = "StageManager"
	root.add_child(stage)
	var character := _build_character()
	var spawner: BossSpawner = auto_free(load(BOSS_SPAWNER).instantiate())
	spawner.character = character
	spawner.spawn_telegraph_time = 0.0
	stage.add_child(spawner)
	spawner.spawn_boss()

	var boss: Enemy = spawner.boss_instance
	var health: Health = boss.get_node("Health")
	health.event_manager.emit_event("on_death", {"self": boss, "damage_context": null})

	assert_float(Wallet.balance(character)).is_equal(float(BossSpawner.bounty_for(spawner.current_loop, false)))


# --- Prices -------------------------------------------------------------------


func test_item_price_rises_each_loop() -> void:
	var analyzer: ItemPriceAnalyzer = auto_free(ItemPriceAnalyzer.new())
	var growth := float(_economy("item_price_growth_per_loop", 0.0))
	var item: Item = load(STAT_ITEM)
	var loop_1 := analyzer.get_price(item, 1)
	assert_int(analyzer.get_price(item, 3)).is_equal(roundi(loop_1 * (1.0 + growth * 2)))

	var weapon: BaseWeapon = load(WEAPON)
	var weapon_1 := analyzer.get_price(weapon, 1)
	assert_int(analyzer.get_price(weapon, 3)).is_equal(roundi(weapon_1 * (1.0 + growth * 2)))


func test_sell_price_follows_the_current_loop_price() -> void:
	var analyzer: ItemPriceAnalyzer = auto_free(ItemPriceAnalyzer.new())
	var ratio := float(_economy("sell_ratio", 0.5))
	var weapon: BaseWeapon = load(WEAPON)
	assert_int(analyzer.get_sell_price(weapon, -1.0, 3)).is_equal(
		maxi(1, roundi(analyzer.get_price(weapon, 3) * ratio)))


# --- Shop events --------------------------------------------------------------


func _open_shop(character: Character, money: float) -> ShopMenu:
	var shop: ShopMenu = auto_free(load("res://src/Scenes/menu/ShopMenu.tscn").instantiate())
	add_child(shop)
	var factory: ItemFactory = auto_free(load("res://src/Systems/Items/ItemFactory.tscn").instantiate())
	add_child(factory)
	shop.item_factory = factory
	character.add_child(_named(ItemHolder.new(), "ItemHolder"))
	character.add_child(_named(WeaponHolder.new(), "WeaponHolder"))
	Wallet.earn(character, money, "test")
	shop.character = character
	GlobalGameState.current_character = character
	return shop


func _named(node: Node, node_name: String) -> Node:
	node.name = node_name
	return node


func _event_names_recorder(names: Array, event_name: String) -> Callable:
	return func(_payload: Dictionary) -> void: names.append(event_name)


func test_shop_emits_enter_reroll_and_purchase_events() -> void:
	var character := _build_character()
	var shop := _open_shop(character, 1000.0)
	var names: Array = []
	for event_name in ["on_shop_enter", "on_reroll", "on_purchase"]:
		character.event_manager.subscribe(event_name, _event_names_recorder(names, event_name))

	shop.show_menu()
	shop.load_items([])
	shop._on_reroll_pressed()
	var card: ShopItemCard = null
	for child in shop.items_container.get_children():
		if child is ShopItemCard and not child.is_resolving():
			card = child
			break
	card.primary_button.pressed.emit()

	assert_array(names).contains_exactly(["on_shop_enter", "on_reroll", "on_purchase"])
	get_tree().paused = false


func test_selling_a_pickup_emits_on_sell() -> void:
	var character := _build_character()
	var shop := _open_shop(character, 0.0)
	character.event_manager.subscribe("on_sell", _record)

	shop.show_menu()
	var item: Item = load(STAT_ITEM)
	shop.load_items([item])
	var card: ShopItemCard = null
	for child in shop.items_container.get_children():
		if child is ShopItemCard:
			card = child
			break
	card.secondary_button.pressed.emit()

	assert_int(_events.size()).is_equal(1)
	assert_float(Wallet.balance(character)).is_equal(float(_events[0]["price"]))
	get_tree().paused = false
