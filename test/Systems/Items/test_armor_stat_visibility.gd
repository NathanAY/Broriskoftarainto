# GdUnit TestSuite for armor being ONE number.
#
# The ArmorModifier used to keep its per-stack bonus to itself and sum it inside
# the damage handler, so an armor item that really did reduce damage left the
# stat panels showing no armor at all (and `Stats.get_stat("armor")` at 0). The
# modifier now publishes that bonus into the `armor` stat, so the number the
# formula uses and the number a panel lists are the same value - these tests pin
# that, plus the inverse: an armor value nothing listens to is never generated.
class_name ArmorStatVisibilityTest
extends GdUnitTestSuite

const ARMOR_SCENE := "res://src/Systems/Items/modifiers/ArmorModifier.tscn"
const ARMOR_SCRIPT := preload("res://src/Systems/Items/modifiers/armor_modifier.gd")
const CHARACTER_UI_SCENE := "res://src/ui/CharacterUI.tscn"
const FACTORY_SCENE := "res://test/SceneWithItemFactory.tscn"


## A character stub with the three children an ItemHolder and the UI resolve
## through. Built by hand (as in `test_stats_list_modifier_stats.gd`) rather than
## from Character.tscn, so no weapon / camera / shop setup comes along.
func _build_character() -> Character:
	var character := Character.new()
	var event_manager := EventManager.new()
	event_manager.name = "EventManager"
	character.add_child(event_manager)
	var stats := Stats.new()
	stats.name = "Stats"
	stats.event_manager = event_manager
	character.add_child(stats)
	var item_holder := ItemHolder.new()
	item_holder.name = "ItemHolder"
	character.add_child(item_holder)
	return character


## The armor item shape the shop hands out: the modifier scene as the payload and
## no stat of its own.
func _armor_item() -> Item:
	return ItemBuilder.make_effect_item("Armor Plate", "Armour", load(ARMOR_SCENE))


## The live ArmorModifier under `node` (or its descendants), or null.
func _armor_modifier(node: Node) -> Node:
	if node.get_script() == ARMOR_SCRIPT:
		return node
	for child in node.get_children():
		var found := _armor_modifier(child)
		if found != null:
			return found
	return null


## The armor the damage formula must have used, derived from the damage it left
## behind: `final = amount * 10 / (10 + armor)`.
func _armor_implied_by(amount: float, damage_after: float) -> float:
	return 10.0 * (amount / damage_after) - 10.0


## Run the damage pipeline hook and return what the hit ended up as.
func _damage_after_armor(character: Node, amount: float) -> float:
	var ctx := DamageContext.new()
	ctx.final_amount = amount
	ctx.target = character
	character.get_node("EventManager").emit_event("before_take_damage", {"damage_context": ctx})
	return ctx.final_amount


# ---------------- the stat is the number the item grants ----------------

## One armor item - a shop buy, a drop, the Configure panel - is worth a full
## `armor_per_stack`. There is no declared baseline to eat its first stack.
func test_one_armor_item_is_worth_its_per_stack_armor() -> void:
	var character := _build_character()
	# Deliberately left out of the tree: a bare `Character.new()` has no Hitbox, so
	# `_ready` would break on it. Nothing here needs a tree - the modifier wires
	# itself through the EventManager, not through `_ready`.
	character.get_node("ItemHolder").add_item(_armor_item())

	var stats: Stats = character.get_node("Stats")
	var modifier: Node = _armor_modifier(character)
	assert_that(modifier).override_failure_message("no ArmorModifier was attached").is_not_null()
	if modifier == null:
		character.free()
		return
	# Derived from the modifier's own numbers rather than a literal, so a balance
	# pass does not have to touch this test.
	var held_stacks: int = modifier.stacks.count(true)
	var expected := float(modifier.get("armor_per_stack")) * float(held_stacks)
	assert_float(stats.get_stat("armor")).override_failure_message(
		"a single armor item published no armor at all").is_equal_approx(expected, 0.001)

	character.free()


func test_a_second_armor_item_adds_another_stack_of_armor() -> void:
	var character := _build_character()
	character.get_node("ItemHolder").add_item(_armor_item())
	character.get_node("ItemHolder").add_item(_armor_item())

	var stats: Stats = character.get_node("Stats")
	var modifier: Node = _armor_modifier(character)
	assert_that(modifier).override_failure_message("no ArmorModifier was attached").is_not_null()
	if modifier == null:
		character.free()
		return
	var expected := float(modifier.get("armor_per_stack")) * float(modifier.stacks.count(true))
	assert_float(stats.get_stat("armor")).is_equal_approx(expected, 0.001)

	character.free()


## A character's declared baseline stands for armor it declares beside the scene,
## which is already in the stat - so the baseline itself must publish nothing, and
## the first armor ITEM is what starts adding on top of it.
func test_a_declared_baseline_publishes_nothing_over_the_characters_own_armor() -> void:
	var character := _build_character()
	var stats: Stats = character.get_node("Stats")
	var declared := 4.0
	stats.add_modifier({"armor": {"flat": declared}})
	# `BaseModifier.attach` is the character path (what CharacterInitializer uses).
	BaseModifier.attach(load(ARMOR_SCENE), character, character.get_node("EventManager") as EventManager)
	assert_float(stats.get_stat("armor")).override_failure_message(
		"the declared baseline double-counted the character's own armor").is_equal_approx(declared, 0.001)

	character.get_node("ItemHolder").add_item(_armor_item())
	var modifier: Node = _armor_modifier(character)
	var expected := declared + float(modifier.get("armor_per_stack"))
	assert_float(stats.get_stat("armor")).is_equal_approx(expected, 0.001)

	character.free()


## The bug itself: armor that reduces damage has to be armor the panels list.
func test_damage_reduction_and_the_stat_report_the_same_armor() -> void:
	var character := _build_character()
	character.get_node("ItemHolder").add_item(_armor_item())
	await get_tree().process_frame

	var stats: Stats = character.get_node("Stats")
	var taken := _damage_after_armor(character, 100.0)
	assert_float(taken).is_less(100.0)
	assert_float(_armor_implied_by(100.0, taken)).is_equal_approx(stats.get_stat("armor"), 0.001)

	character.free()


func test_selling_the_armor_item_takes_the_armor_back_out_of_the_stat() -> void:
	var character := _build_character()
	var item_holder: ItemHolder = character.get_node("ItemHolder")
	var item := _armor_item()
	item_holder.add_item(item)
	item_holder.add_item(item)
	await get_tree().process_frame
	var stats: Stats = character.get_node("Stats")
	var per_stack := float(_armor_modifier(character).get("armor_per_stack"))
	assert_float(stats.get_stat("armor")).is_equal_approx(per_stack * 2.0, 0.001)

	# One copy sold = one stack gone, so the stat drops by exactly one stack.
	item_holder.remove_item(item)
	await get_tree().process_frame
	assert_float(stats.get_stat("armor")).is_equal_approx(per_stack, 0.001)
	assert_float(_damage_after_armor(character, 100.0)).is_equal_approx(
		100.0 * 10.0 / (10.0 + per_stack), 0.001)

	# The last copy gone: the modifier goes with it, and nothing reduces damage.
	item_holder.remove_item(item)
	await get_tree().process_frame
	assert_float(stats.get_stat("armor")).is_equal_approx(0.0, 0.001)
	assert_float(_damage_after_armor(character, 100.0)).is_equal_approx(100.0, 0.001)

	character.free()


func test_character_ui_shows_the_armor_an_item_granted() -> void:
	var character := _build_character()
	var prev_character: Character = GlobalGameState.current_character
	GlobalGameState.current_character = character
	await get_tree().process_frame

	var ui = load(CHARACTER_UI_SCENE).instantiate()
	add_child(ui)
	await get_tree().process_frame
	assert_bool("armor" in ui.value_labels).is_false()

	character.get_node("ItemHolder").add_item(_armor_item())
	await get_tree().process_frame

	assert_bool("armor" in ui.value_labels).override_failure_message(
		"the Character UI listed no armor for an item that grants it").is_true()
	var label: Label = ui.value_labels["armor"]
	var stats: Stats = character.get_node("Stats")
	assert_str(label.text).is_equal("Armor: %.2f" % stats.get_stat("armor"))

	GlobalGameState.current_character = prev_character if is_instance_valid(prev_character) else null
	ui.free()
	character.free()


# ---------------- the inverse: no armor value without its listener ----------------

## Nothing may hand out a bare `armor` number, because on a character with no
## ArmorModifier it shows in the stat panel and changes nothing at all.
func test_generated_items_never_carry_a_bare_armor_stat() -> void:
	var factory_scene = load(FACTORY_SCENE).instantiate()
	add_child(factory_scene)
	var factory: ItemFactory = factory_scene.get_node("ItemFactory")
	factory.rng.seed = 20260913

	for i in 300:
		var item: Item = factory.generate_random_item()
		assert_bool(item.modifiers.has("armor")).override_failure_message(
			"%s grants armor with no ArmorModifier to read it" % item.name).is_false()

	factory_scene.free()


## A buff or debuff carries its stat inside the Buff node, not in
## `item.modifiers`, so it needs its own sweep of the same rule.
func test_generated_buffs_and_debuffs_never_grant_armor_either() -> void:
	var factory_scene = load(FACTORY_SCENE).instantiate()
	add_child(factory_scene)
	var factory: ItemFactory = factory_scene.get_node("ItemFactory")
	factory.rng.seed = 777

	for type in ["buff", "debuff"]:
		var found := 0
		for i in 60:
			var item: Item = factory.get_item_by_type(type)
			for scene in item.effect_scene:
				var buff: Node = scene.instantiate()
				if "modifiers" in buff:
					assert_bool((buff.get("modifiers") as Dictionary).has("armor")).override_failure_message(
						"%s %s grants armor with no ArmorModifier to read it" % [type, item.name]).is_false()
					found += 1
				buff.free()
		assert_int(found).override_failure_message("no %s items were inspected" % type).is_greater(0)

	factory_scene.free()


## Armor stays a candidate (the modifier advertises it) but is not a value an item
## may roll: it reaches the player as the ArmorModifier item instead.
func test_armor_is_a_candidate_but_never_a_rolled_stat_value() -> void:
	var factory_scene = load(FACTORY_SCENE).instantiate()
	add_child(factory_scene)
	var factory: ItemFactory = factory_scene.get_node("ItemFactory")
	assert_that(factory._candidate_stat_names()).contains("armor")
	assert_that(factory._gratable_stat_names()).not_contains("armor")

	for i in 200:
		var item: Item = factory.get_item_by_type("stat")
		for stat_name in item.modifiers:
			assert_that(factory._gratable_stat_names()).contains(str(stat_name))

	factory_scene.free()


## A curse has the same problem as a gift: negated armor is inert on a character
## without the modifier, so it must not be rolled as one.
func test_generated_items_never_curse_armor_either() -> void:
	var factory_scene = load(FACTORY_SCENE).instantiate()
	add_child(factory_scene)
	var factory: ItemFactory = factory_scene.get_node("ItemFactory")
	factory.rng.seed = 4242

	for i in 300:
		var item: Item = factory.generate_random_item()
		for stat_name in item.modifiers:
			assert_str(str(stat_name)).is_not_equal("armor")

	factory_scene.free()