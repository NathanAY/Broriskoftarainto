# GdUnit TestSuite for armor being ONE plain stat.
#
# Armor used to need an ArmorModifier item effect to do anything. It is now an
# ordinary stat like crit: the damage pipeline reads it (`Damage.apply_armor`),
# so the number a panel lists is the number that reduces damage, an armor item
# is a stat item, and the item factory may roll armor like any other stat.
class_name ArmorStatVisibilityTest
extends GdUnitTestSuite

const ARMOR_ITEM := "res://src/Resources/items/ArmorPlate.tres"
const FACTORY_SCENE := "res://test/SceneWithItemFactory.tscn"


## A character stub with the children an ItemHolder resolves through. Built by
## hand rather than from Character.tscn, so no weapon / camera / shop comes along.
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


## Run the armor step and return what the hit ended up as.
func _damage_after_armor(character: Node, amount: float) -> float:
	var ctx := DamageContext.new()
	ctx.final_amount = amount
	Damage.apply_armor(ctx, character.get_node("Stats"))
	return ctx.final_amount


func test_armor_is_a_default_stat() -> void:
	assert_bool(Stats.DEFAULT_STATS.has("armor")).is_true()


func test_armor_item_is_a_plain_stat_item() -> void:
	var item: Item = load(ARMOR_ITEM)
	assert_bool(item.modifiers.has("armor")).is_true()
	assert_bool(ItemTooltip.has_effect_scene(item)).is_false()


## The armor an item grants is the stat, and the stat is what reduces damage.
func test_armor_item_reduces_damage_by_the_stat_it_adds() -> void:
	var character := _build_character()
	var item: Item = load(ARMOR_ITEM)
	var stats: Stats = character.get_node("Stats")
	character.get_node("ItemHolder").add_item(item)

	var armor: float = stats.get_stat("armor")
	assert_float(armor).is_equal_approx(float(item.modifiers["armor"]["flat"]), 0.001)
	assert_float(_damage_after_armor(character, 100.0)).is_equal_approx(100.0 * Damage.armor_multiplier(armor), 0.001)
	character.free()


func test_selling_the_armor_item_takes_the_armor_back_out() -> void:
	var character := _build_character()
	var item_holder: ItemHolder = character.get_node("ItemHolder")
	var item: Item = load(ARMOR_ITEM)
	item_holder.add_item(item)
	item_holder.remove_item(item)

	assert_float(character.get_node("Stats").get_stat("armor")).is_equal(0.0)
	assert_float(_damage_after_armor(character, 100.0)).is_equal(100.0)
	character.free()


func test_generated_stat_items_can_roll_armor() -> void:
	var factory_scene = load(FACTORY_SCENE).instantiate()
	add_child(factory_scene)
	var factory: ItemFactory = factory_scene.get_node("ItemFactory")
	factory.rng.seed = 4242
	assert_that(factory._gratable_stat_names()).contains("armor")

	var rolled_armor := false
	for i in 300:
		if factory.get_item_by_type("stat").modifiers.has("armor"):
			rolled_armor = true
			break
	assert_bool(rolled_armor).override_failure_message(
		"300 generated stat items never rolled armor").is_true()
	factory_scene.free()
