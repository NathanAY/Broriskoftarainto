# GdUnit TestSuite for regen rates being visible in the stat panel.
#
# The four regen_modifier.gd subclasses (flat / percent regen, flat / percent
# life drain) kept their amount in an `@export` and applied it from a timer, so
# the stat panels - which list `Stats` - showed no regen at all. Each subclass now
# publishes its rate into a real stat, so the panel and the tick read one number.
class_name RegenStatVisibilityTest
extends GdUnitTestSuite

const FLAT_REGEN := preload("res://src/Systems/Items/modifiers/flat_regen_modifier.gd")
const PERCENT_REGEN := preload("res://src/Systems/Items/modifiers/percent_regen_modifier.gd")
const FLAT_DRAIN := preload("res://src/Systems/Items/modifiers/flat_life_drain_modifier.gd")
const PERCENT_DRAIN := preload("res://src/Systems/Items/modifiers/percent_life_drain_modifier.gd")
const FLAT_REGEN_SCENE := "res://src/Systems/Items/modifiers/FlatRegenModifier.tscn"
const PERCENT_REGEN_SCENE := "res://src/Systems/Items/modifiers/PercentRegenModifier.tscn"
const FACTORY_SCENE := "res://test/SceneWithItemFactory.tscn"
const CHARACTER_UI_SCENE := "res://src/ui/CharacterUI.tscn"


func _build_character() -> Character:
	var character := Character.new()
	var event_manager := EventManager.new()
	event_manager.name = "EventManager"
	character.add_child(event_manager)
	var stats := Stats.new()
	stats.name = "Stats"
	stats.event_manager = event_manager
	character.add_child(stats)
	var health := Health.new()
	health.name = "Health"
	health.event_manager = event_manager
	character.add_child(health)
	var item_holder := ItemHolder.new()
	item_holder.name = "ItemHolder"
	character.add_child(item_holder)
	return character


## Attach like `BaseModifier.attach` does, i.e. the order ItemHolder uses:
## the node is already parented, wiring comes first, the stack is added after.
func _attach(holder: Node, modifier: Node, stacks: int = 1) -> void:
	holder.get_node("ItemHolder").add_child(modifier)
	modifier.attachEventManager(holder.get_node("EventManager"))
	for i in stacks:
		modifier.add_stack(true)


func _flat_regen() -> Node:
	var modifier := FLAT_REGEN.new()
	modifier.health_delta = 4.0
	modifier.interval = 0.5
	return modifier


func _percent_regen() -> Node:
	var modifier := PERCENT_REGEN.new()
	modifier.health_delta_percent = 0.01
	modifier.interval = 0.5
	return modifier


# ---------------- the rate the panel shows is the rate the timer applies ----------------

## The per-second figure is derived from the modifier's own exports, so a balance
## pass does not have to touch this test - and it is the number that has to match
## what a second of ticking actually does.
func test_flat_regen_publishes_hp_per_second() -> void:
	var character := _build_character()
	var stats: Stats = character.get_node("Stats")
	var modifier := _flat_regen()
	_attach(character, modifier)

	var expected: float = modifier.health_delta / modifier.interval
	assert_float(stats.get_stat("flat_regen_per_second")).is_equal_approx(expected, 0.001)
	# And one second of the timer really is that much health.
	var health: Health = character.get_node("Health")
	health.current_health = 0.0
	for tick in int(1.0 / modifier.interval):
		modifier._on_regen_tick()
	assert_float(health.current_health).is_equal_approx(expected, 0.001)

	character.free()


func test_percent_regen_publishes_percentage_points_per_second() -> void:
	var character := _build_character()
	var stats: Stats = character.get_node("Stats")
	character.get_node("Health").max_health = 200.0
	var modifier := _percent_regen()
	_attach(character, modifier)

	# Percentage points, not a fraction: 1% every 0.5s is 2.00 per second.
	var expected: float = modifier.health_delta_percent / modifier.interval * 100.0
	assert_float(stats.get_stat("percent_regen_per_second")).is_equal_approx(expected, 0.001)

	character.free()


func test_a_second_of_percent_regen_matches_the_published_rate() -> void:
	var character := _build_character()
	var stats: Stats = character.get_node("Stats")
	var health: Health = character.get_node("Health")
	health.max_health = 200.0
	var modifier := _percent_regen()
	_attach(character, modifier)

	health.current_health = 0.0
	for tick in int(1.0 / modifier.interval):
		modifier._on_regen_tick()
	# The stat is a rate against MAX health, so a second of it is that percentage
	# of this character's max health - not the flat HP the flat row reports.
	var as_hp: float = stats.get_stat("percent_regen_per_second") / 100.0 * health.max_health
	assert_float(health.current_health).is_equal_approx(as_hp, 0.001)

	character.free()


func test_stacks_scale_the_published_rate() -> void:
	var character := _build_character()
	var stats: Stats = character.get_node("Stats")
	var modifier := _flat_regen()
	_attach(character, modifier, 2)

	var per_stack: float = modifier.health_delta / modifier.interval
	assert_float(stats.get_stat("flat_regen_per_second")).is_equal_approx(per_stack * 2.0, 0.001)

	# An inactive stack is not healing, so it is not in the rate either.
	modifier.set_stack_active(1, false)
	assert_float(stats.get_stat("flat_regen_per_second")).is_equal_approx(per_stack, 0.001)

	character.free()


# ---------------- a drain lands in the same row, signed ----------------

## The same two items through the real item path, which is the one the shop and
## the Configure panel use - `ItemHolder` stacks and frees the effect nodes itself.
func test_regen_and_drain_items_cancel_through_the_item_holder() -> void:
	var character := _build_character()
	var item_holder: ItemHolder = character.get_node("ItemHolder")
	var stats: Stats = character.get_node("Stats")
	item_holder.add_item(ItemBuilder.make_effect_item(
		"Flat Regen", "regen", load(FLAT_REGEN_SCENE)))
	item_holder.add_item(ItemBuilder.make_effect_item(
		"Life Drain", "drain", load("res://src/Systems/Items/modifiers/FlatLifeDrainModifier.tscn")))

	var regen: float = stats.get_stat("flat_regen_per_second")
	assert_float(regen).override_failure_message(
		"regen 4 HP / 0.5s and a 2 HP / 0.5s drain did not cancel to 4.00 HP/s").is_equal_approx(4.0, 0.001)

	character.free()


func test_a_flat_drain_subtracts_from_the_flat_regen_rate() -> void:
	var character := _build_character()
	var stats: Stats = character.get_node("Stats")
	var drain := FLAT_DRAIN.new()
	drain.health_delta = -2.0
	drain.interval = 0.5
	_attach(character, drain)
	_attach(character, _flat_regen())

	var regen: float = 4.0 / 0.5
	var loss: float = -2.0 / 0.5
	assert_float(stats.get_stat("flat_regen_per_second")).is_equal_approx(regen + loss, 0.001)

	character.free()


func test_a_percent_drain_subtracts_from_the_percent_regen_rate() -> void:
	var character := _build_character()
	var stats: Stats = character.get_node("Stats")
	var drain := PERCENT_DRAIN.new()
	drain.health_delta_percent = -0.01
	drain.interval = 0.5
	_attach(character, drain)

	assert_float(stats.get_stat("percent_regen_per_second")).is_equal_approx(-2.0, 0.001)

	character.free()


func test_a_drain_alone_still_lists_the_row() -> void:
	var character := _build_character()
	var stats: Stats = character.get_node("Stats")
	_attach(character, FLAT_DRAIN.new())
	# A character with only a drain has no regen, but the panel still has to show
	# that it is losing health - the row is the net rate, not just a positive one.
	assert_that(stats.display_stat_names()).contains("flat_regen_per_second")

	character.free()


# ---------------- the panel ----------------

func test_character_ui_lists_the_regen_rates() -> void:
	var character := _build_character()
	var prev_character: Character = GlobalGameState.current_character
	GlobalGameState.current_character = character
	await get_tree().process_frame

	var ui = load(CHARACTER_UI_SCENE).instantiate()
	add_child(ui)
	await get_tree().process_frame
	assert_bool("flat_regen_per_second" in ui.value_labels).is_false()

	_attach(character, _flat_regen())
	_attach(character, _percent_regen())
	await get_tree().process_frame

	assert_bool("flat_regen_per_second" in ui.value_labels).is_true()
	assert_bool("percent_regen_per_second" in ui.value_labels).is_true()
	# The row carries a hint to hover, like every other stat row.
	var row: Control = ui.value_labels["flat_regen_per_second"].get_parent()
	row.emit_signal("mouse_entered")
	assert_str(ui.tooltip.label.text).contains(ItemTooltip.stat_hint("flat_regen_per_second"))

	GlobalGameState.current_character = prev_character if is_instance_valid(prev_character) else null
	ui.free()
	character.free()


func test_the_row_goes_away_when_the_last_regen_item_is_sold() -> void:
	var character := _build_character()
	var item := ItemBuilder.make_effect_item("Flat Regen", "regen", load(FLAT_REGEN_SCENE))
	character.get_node("ItemHolder").add_item(item)
	var stats: Stats = character.get_node("Stats")
	assert_that(stats.display_stat_names()).contains("flat_regen_per_second")

	character.get_node("ItemHolder").remove_item(item)
	await get_tree().process_frame
	assert_float(stats.get_stat("flat_regen_per_second")).is_zero()
	assert_that(stats.display_stat_names()).not_contains("flat_regen_per_second")

	character.free()


## A character's declared baseline regen (the Wildling's variant scene) is a full
## stack of regen: its amount lives on the modifier, not on a value the character
## declares beside the scene, so there is no declared value to double up with.
func test_a_declared_baseline_regen_shows_in_full() -> void:
	var character := _build_character()
	var stats: Stats = character.get_node("Stats")
	var baseline := FLAT_REGEN.new()
	baseline.health_delta = 1.0
	baseline.interval = 0.5
	character.get_node("ItemHolder").add_child(baseline)
	# The three steps `BaseModifier.attach` performs, on an instance this test can
	# configure. attach() only takes a scene, so the flag is set here too - it is
	# exactly what marks the stack as declared rather than held.
	baseline.is_declared_baseline = true
	baseline.attachEventManager(character.get_node("EventManager") as EventManager)
	baseline.add_stack(true)

	var expected: float = baseline.health_delta / baseline.interval
	assert_bool(baseline.is_declared_baseline).is_true()
	assert_float(stats.get_stat("flat_regen_per_second")).is_equal_approx(expected, 0.001)

	character.free()


# ---------------- the factory must not hand out an inert rate ----------------

func test_generated_items_never_grant_a_bare_regen_rate() -> void:
	var factory_scene = load(FACTORY_SCENE).instantiate()
	add_child(factory_scene)
	var factory: ItemFactory = factory_scene.get_node("ItemFactory")
	factory.rng.seed = 90210

	for i in 300:
		var item: Item = factory.generate_random_item()
		for stat_name in item.modifiers:
			assert_bool(ItemFactory.LISTENER_ONLY_STATS.has(str(stat_name))).override_failure_message(
				"%s grants %s with no regen modifier to apply it" % [item.name, stat_name]).is_false()

	factory_scene.free()