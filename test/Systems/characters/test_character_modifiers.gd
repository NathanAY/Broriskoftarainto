# GdUnit TestSuite for CharacterData.modifiers - the single, universal way a
# character declares what makes it different from the default Stats.
#
# One list, two entry kinds (dispatched by type, no stat names in code):
#   Dictionary  -> Stats.add_modifier        (the value, e.g. armor)
#   PackedScene -> a wired BaseModifier      (the behavior that reads it)
class_name CharacterModifiersTest
extends GdUnitTestSuite

const BRAWLER := "res://src/Assets/character/brawler/Brawler.tres"
const WILDLING := "res://src/Assets/character/wildling/Wildling.tres"
const RANGER := "res://src/Assets/character/ranger/Ranger.tres"
const CHARACTER_SCENE := "res://src/Systems/Character.tscn"
const ARMOR_SCENE := "res://src/Systems/Items/modifiers/ArmorModifier.tscn"
const ARMOR_SCRIPT := preload("res://src/Systems/Items/modifiers/armor_modifier.gd")


func _spawn_character(character_path: String) -> Node:
	var prev_character: Variant = GlobalGameState.starting_character
	var prev_weapons: Array = GlobalGameState.starting_weapons.duplicate()
	var prev_items: Array = GlobalGameState.starting_items.duplicate()
	GlobalGameState.starting_character = character_path
	GlobalGameState.starting_weapons = []
	GlobalGameState.starting_items = []

	var character: Node = load(CHARACTER_SCENE).instantiate()
	add_child(character)
	await get_tree().process_frame

	GlobalGameState.starting_character = prev_character
	GlobalGameState.starting_weapons = prev_weapons
	GlobalGameState.starting_items = prev_items
	return character


func _modifier_scenes(character: CharacterData) -> Array:
	var found: Array = []
	for mod in character.modifiers:
		if mod is PackedScene:
			found.append(mod)
	return found


func _armor_modifier_nodes(node: Node) -> Array:
	var found: Array = []
	if node.get_script() == ARMOR_SCRIPT:
		found.append(node)
	for child in node.get_children():
		found.append_array(_armor_modifier_nodes(child))
	return found


## Emits the damage pipeline hook and returns the resulting damage.
func _damage_after_armor(character: Node, amount: float) -> float:
	var ctx := DamageContext.new()
	ctx.final_amount = amount
	# `target` is read by the damage-number spawner that also listens to
	# `before_take_damage`.
	ctx.target = character
	character.get_node("EventManager").emit_event("before_take_damage", {"damage_context": ctx})
	return ctx.final_amount


# ---------------- the one convention ----------------

func test_armor_is_declared_only_in_modifiers_never_base_stats() -> void:
	for path in [BRAWLER, WILDLING, "res://src/Assets/character/soldier/Soldier.tres"]:
		var character: CharacterData = load(path)
		# `base_stats` is the archetype's stat block only; a stat that needs a
		# modifier to do anything never belongs there.
		assert_bool(character.base_stats.has("armor")).override_failure_message(
			"%s declares armor in base_stats" % character.display_name).is_false()
		var declares_armor := false
		for mod in character.modifiers:
			if mod is Dictionary and mod.has("armor"):
				declares_armor = true
		assert_bool(declares_armor).override_failure_message(
			"%s has no armor modifier entry" % character.display_name).is_true()


func test_armor_value_and_behavior_live_in_the_same_list() -> void:
	for path in [BRAWLER, WILDLING]:
		var character: CharacterData = load(path)
		# One list, both kinds: the value dict and the modifier scene that
		# makes the value reduce damage.
		var has_value := false
		var has_behavior := false
		for mod in character.modifiers:
			if mod is PackedScene and mod.resource_path == ARMOR_SCENE:
				has_behavior = true
			elif mod is Dictionary and mod.has("armor"):
				has_value = true
		assert_bool(has_value).is_true()
		assert_bool(has_behavior).is_true()


# ---------------- values are applied ----------------

func test_stat_dict_entry_reaches_stats() -> void:
	var character := await _spawn_character(BRAWLER)
	var stats: Stats = character.get_node("Stats")
	assert_float(stats.get_stat("armor")).is_equal_approx(4.0, 0.001)
	assert_float(stats.get_stat("health")).is_equal_approx(95.0, 0.001)
	# 1.15 base * 1.1 from the character modifier
	assert_float(stats.get_stat("damage")).is_equal_approx(1.265, 0.001)
	character.free()


func test_character_modifier_scene_is_attached_and_wired() -> void:
	var character := await _spawn_character(BRAWLER)
	assert_int(_armor_modifier_nodes(character).size()).is_equal(1)
	var modifier: Node = _armor_modifier_nodes(character)[0]
	# attach() is the full contract: wired to the event manager, one live stack.
	assert_that(modifier.event_manager).is_not_null()
	assert_int(modifier.stacks.size()).is_equal(1)
	assert_bool(modifier.stacks[0]).is_true()
	character.free()


func test_declared_behavior_makes_the_declared_value_apply() -> void:
	var character := await _spawn_character(BRAWLER)
	# armor 4 -> 10 / (10 + 4)
	assert_float(_damage_after_armor(character, 100.0)).is_equal_approx(100.0 * 10.0 / 14.0, 0.001)
	character.free()


func test_two_characters_using_the_same_convention() -> void:
	var brawler := await _spawn_character(BRAWLER)
	var brawler_damage := _damage_after_armor(brawler, 100.0)
	brawler.free()

	var wildling := await _spawn_character(WILDLING)
	var wildling_armor: float = wildling.get_node("Stats").get_stat("armor")
	var wildling_damage := _damage_after_armor(wildling, 100.0)
	wildling.free()

	# Same declaration shape, different numbers - nothing character-specific.
	assert_float(wildling_armor).is_equal_approx(14.0, 0.001)
	# armor 14 -> 10 / (10 + 14)
	assert_float(wildling_damage).is_equal_approx(100.0 * 10.0 / 24.0, 0.001)
	# Brawler's lower armor means it takes more damage.
	assert_float(brawler_damage).is_greater(wildling_damage)


func test_character_without_modifier_scenes_declares_no_behavior() -> void:
	var character := await _spawn_character(RANGER)
	var data: CharacterData = load(RANGER)
	assert_int(_modifier_scenes(data).size()).is_equal(0)
	assert_int(_armor_modifier_nodes(character).size()).is_equal(0)
	character.free()


# ---------------- universality ----------------

func test_a_value_without_its_behavior_stays_inert() -> void:
	# Proves the behavior really comes from the scene entry: a stat-only
	# character has the number but takes full damage.
	var character := await _spawn_character(BRAWLER)
	var modifier: Node = _armor_modifier_nodes(character)[0]
	modifier.detach()
	assert_float(character.get_node("Stats").get_stat("armor")).is_equal_approx(4.0, 0.001)
	assert_float(_damage_after_armor(character, 100.0)).is_equal_approx(100.0, 0.001)
	character.free()


func test_extra_behavior_scenes_attach_without_code_changes() -> void:
	# The initializer only forwards scenes, so an unrelated modifier (energy
	# shield) can be added to a character by listing it.
	var character := await _spawn_character(BRAWLER)
	var item_holder: ItemHolder = character.get_node("ItemHolder")
	var shield: BaseModifier = BaseModifier.attach(
		load("res://src/Systems/Items/modifiers/EnergyShieldModifier.tscn"),
		item_holder,
		character.get_node("EventManager") as EventManager)
	assert_that(shield).is_not_null()
	assert_bool(character.get_node("Stats").stats.has("energy_shield")).is_true()
	character.free()


func test_attach_rejects_a_scene_that_is_not_a_modifier() -> void:
	# A misconfigured declaration must fail loudly instead of silently doing
	# nothing: the scene's root does not implement the modifier contract.
	var host := Node.new()
	host.name = "Host"
	add_child(host)
	var plain := Node.new()
	plain.name = "NotAModifier"
	var bogus := PackedScene.new()
	assert_int(bogus.pack(plain)).is_equal(OK)
	var em := EventManager.new()
	em.name = "EventManager"
	host.add_child(em)

	# Creation itself is duck-typed (buffs self-wire in _ready)...
	assert_that(BaseModifier.instantiate_attached(bogus, host)).is_not_null()
	assert_int(host.get_child_count()).is_equal(2)
	# ...but the modifier entry point rejects a non-modifier and cleans up.
	assert_object(BaseModifier.attach(bogus, host, em)).is_null()
	assert_int(host.get_child_count()).is_equal(2)
	assert_object(BaseModifier.attach(null, host, em)).is_null()
	assert_object(BaseModifier.attach(load(ARMOR_SCENE), host, null)).is_null()
	host.free()
	plain.free()


func test_modifier_scene_entry_shows_up_in_the_character_tooltip() -> void:
	var character: CharacterData = load(BRAWLER)
	var text := "\n".join(CharacterTooltip.tooltip_lines(character))
	assert_str(text).contains("armor flat: 4")
	# The declared behavior is visible in the select screen too.
	assert_str(text).contains("effect: Armor")
	assert_str(text).not_contains("base armor")
