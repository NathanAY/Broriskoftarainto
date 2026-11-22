# GdUnit TestSuite for CharacterData.modifiers - the single, universal way a
# character declares the behaviors that make it different from the default
# Stats. Plain numbers, armor included, live in `base_stats`.
#
# One list, two entry kinds (dispatched by type, no stat names in code):
#   Dictionary  -> Stats.add_modifier        (a value, e.g. attack_speed)
#   PackedScene -> a wired BaseModifier      (a behavior, e.g. regen)
class_name CharacterModifiersTest
extends GdUnitTestSuite

const BRAWLER := "res://src/Assets/character/brawler/Brawler.tres"
const SOLDIER := "res://src/Assets/character/soldier/Soldier.tres"
const RANGER := "res://src/Assets/character/ranger/Ranger.tres"
const WILDLING := "res://src/Assets/character/wildling/Wildling.tres"
const CHARACTER_SCENE := "res://src/Systems/Character.tscn"
const FLAT_REGEN_SCENE := "res://src/Systems/Items/modifiers/FlatRegenModifier.tscn"
const REGEN_SCRIPT := preload("res://src/Systems/Items/modifiers/flat_regen_modifier.gd")


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


## A regen scene instantiated from FlatRegenModifier.tscn keeps that script, so
## the search matches both the shared default and a character's own variant.
func _regen_modifier_nodes(node: Node) -> Array:
	var found: Array = []
	if node.get_script() == REGEN_SCRIPT:
		found.append(node)
	for child in node.get_children():
		found.append_array(_regen_modifier_nodes(child))
	return found


## The scene a character declares for regen, or null if it declares none.
## Matched on the scene's own script, so a character may declare the shared
## FlatRegenModifier or a configured variant of it.
func _declared_regen_scene(data: CharacterData) -> PackedScene:
	for mod in data.modifiers:
		if not mod is PackedScene:
			continue
		var probe: Node = mod.instantiate()
		var is_regen: bool = probe.get_script() == REGEN_SCRIPT
		probe.free()
		if is_regen:
			return mod
	return null


## Runs the armor step and returns the resulting damage.
func _damage_after_armor(character: Node, amount: float) -> float:
	var ctx := DamageContext.new()
	ctx.final_amount = amount
	# The armor step `Health.apply_damage()` runs before any listener.
	Damage.apply_armor(ctx, character.get_node("Stats"))
	return ctx.final_amount


# ---------------- base stats are applied ----------------

func test_base_stats_reach_stats() -> void:
	var data: CharacterData = load(BRAWLER)
	var character := await _spawn_character(BRAWLER)
	var stats: Stats = character.get_node("Stats")
	assert_float(stats.get_stat("armor")).is_equal_approx(float(data.base_stats["armor"]), 0.001)
	assert_float(stats.get_stat("health")).is_equal_approx(float(data.base_stats["health"]), 0.001)
	assert_float(stats.get_stat("damage")).is_equal_approx(_expected_damage(data), 0.001)
	character.free()


## Armor is a plain stat the damage pipeline reads: no modifier is attached.
func test_base_stat_armor_reduces_damage_with_no_modifier() -> void:
	var character := await _spawn_character(BRAWLER)
	var armor: float = character.get_node("Stats").get_stat("armor")
	assert_float(armor).is_greater(0.0)
	assert_float(_damage_after_armor(character, 100.0)).is_equal_approx(100.0 * Damage.armor_multiplier(armor), 0.001)
	assert_int(_modifier_scenes(load(BRAWLER)).size()).is_equal(0)
	character.free()


func test_two_characters_take_their_own_armor() -> void:
	var brawler := await _spawn_character(BRAWLER)
	var brawler_armor: float = brawler.get_node("Stats").get_stat("armor")
	var brawler_damage := _damage_after_armor(brawler, 100.0)
	brawler.free()

	var soldier := await _spawn_character(SOLDIER)
	var soldier_armor: float = soldier.get_node("Stats").get_stat("armor")
	var soldier_damage := _damage_after_armor(soldier, 100.0)
	soldier.free()

	# Nothing character-specific: each takes the mitigation its own armor implies.
	assert_float(brawler_damage).is_equal_approx(100.0 * Damage.armor_multiplier(brawler_armor), 0.001)
	assert_float(soldier_damage).is_equal_approx(100.0 * Damage.armor_multiplier(soldier_armor), 0.001)


func test_character_without_modifier_scenes_declares_no_behavior() -> void:
	var data: CharacterData = load(RANGER)
	assert_int(_modifier_scenes(data).size()).is_equal(0)


# ---------------- universality ----------------

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
	assert_object(BaseModifier.attach(load(FLAT_REGEN_SCENE), host, null)).is_null()
	host.free()
	plain.free()


func test_base_armor_shows_up_in_the_character_tooltip() -> void:
	var character: CharacterData = load(BRAWLER)
	var text := "\n".join(CharacterTooltip.tooltip_lines(character))
	assert_str(text).contains("base armor: %s" % str(character.base_stats["armor"]))
	assert_str(text).not_contains("effect: Armor")


# ---------------- a character brings its own regen numbers ----------------

# The Wildling's regen is a flat HP tick, and like every other stat-driven
# behavior it is declared in `modifiers` rather than in `base_stats`. A regen
# amount is an export on the modifier itself, so the character
# lists a scene configured with its own numbers instead of the shop default.

func test_declared_regen_is_attached_and_wired() -> void:
	var character := await _spawn_character(WILDLING)
	var nodes := _regen_modifier_nodes(character)
	assert_int(nodes.size()).override_failure_message(
		"expected exactly one regen modifier under the Wildling").is_equal(1)
	if nodes.is_empty():
		character.free()
		return
	var regen: Node = nodes[0]
	assert_that(regen.event_manager).is_not_null()
	assert_int(regen.stacks.size()).is_equal(1)
	character.free()


func test_declared_regen_carries_the_characters_own_amount() -> void:
	var data: CharacterData = load(WILDLING)
	var declared := _declared_regen_scene(data)
	if declared == null:
		return
	var configured: Node = declared.instantiate()
	var shop_default: Node = load(FLAT_REGEN_SCENE).instantiate()
	# The Wildling is the fragile archetype; at the shop item's rate it would
	# out-heal anything that hits it. Its own declaration has to be weaker.
	assert_float(float(configured.health_delta)).override_failure_message(
		"%s declares regen at the shop item's rate" % data.display_name).is_less(
		float(shop_default.health_delta))
	assert_float(float(configured.interval)).is_equal(float(shop_default.interval))
	configured.free()
	shop_default.free()


func test_one_regen_tick_heals_the_declared_amount() -> void:
	var character := await _spawn_character(WILDLING)
	var nodes := _regen_modifier_nodes(character)
	if nodes.is_empty():
		character.free()
		return
	var regen: Node = nodes[0]
	var health: Health = character.get_node("Health")
	health.current_health = health.max_health - 10.0
	regen.call("_on_regen_tick")
	assert_float(health.current_health).is_equal_approx(
		health.max_health - 10.0 + float(regen.health_delta), 0.001)
	character.free()


func test_declared_regen_shows_its_own_amount_on_the_character_card() -> void:
	var data: CharacterData = load(WILDLING)
	var declared := _declared_regen_scene(data)
	if declared == null:
		return
	var configured: Node = declared.instantiate()
	# The card is built by reflecting on the scene, so the configured number -
	# not the scene's export default - is what the player reads.
	assert_str("\n".join(CharacterTooltip.tooltip_lines(data))).contains(
		str(configured.health_delta))
	assert_str("\n".join(CharacterTooltip.tooltip_lines(data))).contains("Flat Regen")
	configured.free()


func test_wildling_declares_a_regen_behavior() -> void:
	var data: CharacterData = load(WILDLING)
	assert_object(_declared_regen_scene(data)).override_failure_message(
		"%s declares no regen modifier scene" % data.display_name).is_not_null()


# ---------------- helpers ----------------

## base_stats damage folded with any percent damage modifiers.
func _expected_damage(data: CharacterData) -> float:
	var value := float(data.base_stats.get("damage", Stats.DEFAULT_STATS["damage"]))
	for mod in data.modifiers:
		if mod is Dictionary and mod.has("damage"):
			value *= 1.0 + float(mod["damage"].get("percent", 0.0))
	return value


## Every CharacterData .tres under src/Assets/character.
func _all_character_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	_collect_characters("res://src/Assets/character", paths)
	return paths


func _collect_characters(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_characters(full, out)
		elif entry.ends_with(".tres"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
