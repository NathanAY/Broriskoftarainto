# RunHistory: effects that pay out are recorded on the character, merged per
# stage, shown as floating text, and listed in the Run history tab.
# Amounts are derived from config / the modifier under test, never literals.
class_name RunHistoryTest
extends GdUnitTestSuite

const DIR := "res://src/Systems/Items/modifiers/"
const CHARACTER_UI_SCENE := "res://src/ui/CharacterUI.tscn"
const SPAWNER_SCENE := "res://src/ui/numberspawn/RunEventSpawner.tscn"

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
	health.event_manager = event_manager
	health.name = "Health"
	character.add_child(health)
	health.max_health = 50.0
	health.current_health = 50.0
	return character


func _attach(character: Character, scene_name: String) -> BaseModifier:
	return BaseModifier.attach(load(DIR + scene_name + ".tscn"), character, character.event_manager)


func _kill(character: Character, target: Node) -> void:
	var ctx := DamageContext.new()
	ctx.target = target
	character.event_manager.emit_event("on_kill", {"damage_context": ctx})


func _record_event(event: Dictionary) -> void:
	_events.append(event)


func test_a_bounty_payout_is_recorded_and_announced() -> void:
	var character := _build_character()
	character.event_manager.subscribe("on_run_event", _record_event)
	var modifier := _attach(character, "BountyMarkModifier")
	var enemy: Node2D = auto_free(Node2D.new())
	modifier.mark(enemy)

	_kill(character, enemy)

	assert_int(character.run_history.size()).is_equal(1)
	var entry: Dictionary = character.run_history[0]
	assert_str(entry["source"]).is_equal(modifier.display_name)
	assert_str(entry["what"]).is_equal("coins")
	assert_float(entry["amount"]).is_equal(Wallet.balance(character))
	assert_int(_events.size()).is_equal(1)
	assert_float(_events[0]["amount"]).is_equal(Wallet.balance(character))


func test_repeats_in_one_stage_merge_into_one_entry_with_a_count() -> void:
	var character := _build_character()
	var modifier: StatOnKillModifier = _attach(character, "StatOnKillModifier")
	modifier.target_stat = "health"

	_kill(character, auto_free(Node2D.new()))
	_kill(character, auto_free(Node2D.new()))

	assert_int(character.run_history.size()).is_equal(1)
	var entry: Dictionary = character.run_history[0]
	assert_int(entry["count"]).is_equal(2)
	assert_float(entry["amount"]).is_equal_approx(2.0 * modifier.add_amount, 0.0001)
	assert_str(RunHistory.describe(entry)).contains("(x2)")


func test_a_cost_is_recorded_as_a_loss() -> void:
	var character := _build_character()
	var modifier := _attach(character, "TaxCollectorModifier")
	Wallet.earn(character, 50.0, "kill")

	Wallet.payday(character, 1)

	var tax := _find(character.run_history, modifier.display_name)
	assert_float(tax["amount"]).is_equal(Wallet.balance(character) - 50.0)
	assert_float(tax["amount"]).is_less(0.0)
	assert_str(RunHistory.amount_text(tax["what"], tax["amount"])).starts_with("-")


func test_payday_records_the_stock_dividend() -> void:
	var character := _build_character()
	character.stats.set_base_stat("stock_investment", 3.0)

	var breakdown := Wallet.payday(character, 1)

	var dividend := _find(character.run_history, Wallet.PAYDAY_LABELS["dividend"])
	assert_float(dividend["amount"]).is_equal(breakdown["dividend"])


func test_a_holder_that_is_not_the_player_records_nothing() -> void:
	var enemy: Node2D = auto_free(Node2D.new())
	RunHistory.record(enemy, "Bounty Mark", "coins", 5.0)
	# Nothing to assert on the enemy: reaching here without an error is the check,
	# and a zero amount must not create an entry either.
	var character := _build_character()
	RunHistory.record(character, "Bounty Mark", "coins", 0.0)
	assert_array(character.run_history).is_empty()


## A plain body with an event bus and the spawner, in the tree. A bare
## `Character` cannot enter the tree (its `_ready` needs the full scene), and
## the spawner only needs a positioned parent of its bus.
func _spawner_body() -> EventManager:
	var body: Node2D = auto_free(Node2D.new())
	var event_manager := EventManager.new()
	event_manager.name = "EventManager"
	body.add_child(event_manager)
	var spawner: RunEventSpawner = load(SPAWNER_SCENE).instantiate()
	spawner.event_manager = event_manager
	body.add_child(spawner)
	add_child(body)
	return event_manager


func _announce(event_manager: EventManager, source: String, amount: float) -> void:
	event_manager.emit_event("on_run_event", {"source": source, "what": "coins", "amount": amount})


func test_spawner_shows_floating_text_for_a_run_event() -> void:
	var event_manager := _spawner_body()
	var count_before := _floating_texts().size()

	_announce(event_manager, "Bounty Mark", 7.0)

	var texts := _floating_texts()
	assert_int(texts.size()).is_equal(count_before + 1)
	var label: Label = texts[-1].get_node("Label")
	assert_str(label.text).contains("Bounty Mark")
	assert_str(label.text).contains(RunHistory.amount_text("coins", 7.0))
	assert_that(label.modulate).is_equal(RunEventSpawner.COINS_COLOR)


func test_two_events_in_one_frame_do_not_overlap() -> void:
	var event_manager := _spawner_body()
	var count_before := _floating_texts().size()

	_announce(event_manager, "Interest", 2.0)
	_announce(event_manager, "Stock Investment dividend", 3.0)

	var texts := _floating_texts().slice(count_before)
	assert_int(texts.size()).is_equal(2)
	assert_float((texts[0] as Node2D).global_position.y).is_not_equal((texts[1] as Node2D).global_position.y)


func test_character_menu_has_a_run_history_tab_listing_entries() -> void:
	var character := _build_character()
	character.add_child(_named(ItemHolder.new(), "ItemHolder"))
	character.add_child(_named(WeaponHolder.new(), "WeaponHolder"))
	RunHistory.record(character, "Bounty Mark", "coins", 7.0)
	var prev_character = GlobalGameState.current_character
	GlobalGameState.current_character = character

	var ui = auto_free(load(CHARACTER_UI_SCENE).instantiate())
	add_child(ui)

	assert_str(ui.stats_tabs.get_tab_title(2)).is_equal("Run history")
	var lines: Array[String] = []
	for child in ui.history_container.get_children():
		lines.append((child as Label).text)
	assert_array(lines).contains(["Stage 1", RunHistory.describe(character.run_history[0])])

	GlobalGameState.current_character = prev_character if is_instance_valid(prev_character) else null


static func _find(history: Array, source: String) -> Dictionary:
	for entry in history:
		if entry["source"] == source:
			return entry
	return {}


func _floating_texts() -> Array[Node]:
	return get_tree().root.find_children("*", "FloatingNumber", true, false)


func _named(node: Node, node_name: String) -> Node:
	node.name = node_name
	return node
