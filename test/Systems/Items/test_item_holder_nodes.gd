# GdUnit tests for the debug visibility of ItemHolder items.
# An item is a Resource, so nothing of it shows up in the scene tree unless the
# holder builds a node for it. These suites pin the debugging contract:
#   - every added item owns one node named after the item, under the ItemHolder
#   - an item's effect/modifier node stays a sibling, so add_item/remove_item
#     keep finding it by scanning the ItemHolder's direct children
#   - items without an effect_scene are represented too
#   - items are shared Resources, so two holders each get their own node
#   - adding the same item twice gives distinct names, removing frees the node
class_name ItemHolderNodesTest
extends GdUnitTestSuite

const ARMOUR := "res://src/Resources/items/ArmorPlate.tres"    # has an effect_scene
const BOOTS := "res://src/Resources/items/BootsOfSpeed.tres"   # no effect_scene
const EFFECT_SCENE := "res://src/Systems/Items/Buffs/buff.tscn"


func _character_without_items() -> Dictionary:
	var runner := scene_runner("res://test/TestScene.tscn")
	var test_scene := runner.scene()
	get_tree().current_scene = test_scene
	var character: Character = test_scene.get_node("Character")
	for item in character.item_holder.items.duplicate():
		character.item_holder.remove_item(item)
	return {"test_scene": test_scene, "character": character}


func test_adding_an_item_creates_a_node_named_after_it() -> void:
	var ctx := _character_without_items()
	var character: Character = ctx["character"]
	var item: Item = load(ARMOUR)

	character.item_holder.add_item(item)

	assert_that(character.item_holder.has_node("Armour plate")).is_true()
	var node: ItemNode = character.item_holder.get_node("Armour plate")
	assert_that(node.item).is_same(item)
	assert_that(node.get_parent()).is_same(character.item_holder)

	ctx["test_scene"].free()


func test_item_node_sits_next_to_the_effect_node() -> void:
	var ctx := _character_without_items()
	var character: Character = ctx["character"]

	character.item_holder.add_item(load(ARMOUR))

	# the effect node stays a direct child of the ItemHolder: add_item and
	# remove_item look it up by scanning the direct children
	var effect: Node = null
	for child in character.item_holder.get_children():
		if child.scene_file_path.ends_with("ArmorModifier.tscn"):
			effect = child
	assert_that(effect).is_not_null()
	assert_that(effect.get_parent()).is_same(character.item_holder)

	ctx["test_scene"].free()


func test_item_without_effect_scene_still_gets_a_node() -> void:
	var ctx := _character_without_items()
	var character: Character = ctx["character"]

	character.item_holder.add_item(load(BOOTS))

	assert_that(character.item_holder.has_node("Boots of speed")).is_true()
	assert_that(character.item_holder.get_node("Boots of speed").item).is_same(load(BOOTS))

	ctx["test_scene"].free()


func test_two_holders_sharing_an_item_each_get_their_own_node() -> void:
	var ctx := _character_without_items()
	var character: Character = ctx["character"]
	# items are shared Resources (character.gd adds `load(path)` without a
	# duplicate), so the node must belong to the holder, not to the item
	var other: Character = load("res://src/Systems/Character.tscn").instantiate()
	ctx["test_scene"].add_child(other)
	var item: Item = load(ARMOUR)

	character.item_holder.add_item(item)
	other.item_holder.add_item(item)

	var mine: ItemNode = character.item_holder.get_node("Armour plate")
	var theirs: ItemNode = other.item_holder.get_node("Armour plate")
	assert_that(mine).is_not_same(theirs)
	assert_that(mine.item).is_same(item)
	assert_that(theirs.item).is_same(item)

	ctx["test_scene"].free()


func test_adding_the_same_item_twice_gives_distinct_names() -> void:
	var ctx := _character_without_items()
	var character: Character = ctx["character"]
	var item: Item = load(BOOTS)

	character.item_holder.add_item(item)
	character.item_holder.add_item(item)

	assert_that(character.item_holder.has_node("Boots of speed")).is_true()
	assert_that(character.item_holder.has_node("Boots of speed2")).is_true()
	assert_that(character.item_holder.items.size()).is_equal(2)

	ctx["test_scene"].free()


# The item nodes must not be mistaken for the item's effect node. Effect nodes
# are matched by scene path, and both sides of that comparison are empty for the
# in-memory scenes ItemBuilder packs, so an item node would otherwise swallow
# the match and the real effect would never be created.
func test_item_nodes_do_not_hijack_the_effect_lookup() -> void:
	var ctx := _character_without_items()
	var character: Character = ctx["character"]
	var effect_scene := load(EFFECT_SCENE)
	var item: Item = ItemBuilder.make_buff_item("Buff probe", "Buff", "attack_speed", {"flat": 1.0}, effect_scene)
	# make_buff_item re-packs the scene in memory, so its path is empty
	assert_that(String(item.effect_scene[0].resource_path)).is_equal("")

	character.item_holder.add_item(item)
	character.item_holder.add_item(item)

	var buffs := 0
	for child in character.item_holder.get_children():
		if child is Buff:
			buffs += 1
	# the second item stacks into the first item's effect node
	assert_that(buffs).is_equal(1)
	assert_that(character.item_holder.items.size()).is_equal(2)

	ctx["test_scene"].free()


func test_two_items_with_the_same_effect_scene_share_one_effect_node() -> void:
	var ctx := _character_without_items()
	var character: Character = ctx["character"]

	character.item_holder.add_item(load(ARMOUR))
	character.item_holder.add_item(load(ARMOUR))

	var modifiers := 0
	for child in character.item_holder.get_children():
		if child.scene_file_path.ends_with("ArmorModifier.tscn"):
			modifiers += 1
	assert_that(modifiers).is_equal(1)

	ctx["test_scene"].free()


func test_removing_an_item_frees_its_node() -> void:
	var ctx := _character_without_items()
	var character: Character = ctx["character"]
	var item: Item = load(BOOTS)
	character.item_holder.add_item(item)
	var node: ItemNode = character.item_holder.get_node("Boots of speed")

	character.item_holder.remove_item(item)

	assert_that(character.item_holder.items.has(item)).is_false()
	# queue_free only takes effect at the end of the frame
	assert_that(node.is_queued_for_deletion()).is_true()

	ctx["test_scene"].free()
