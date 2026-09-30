# GdUnit tests for items that carry several effect scenes.
#
# `Item.effect_scene` is an Array[PackedScene]: one item can bring several
# behaviors at once (e.g. damage handling + life leech). `ItemHolder` must give
# every scene its own effect node (deduplicated per scene across copies), wire
# each one to the EventManager, add one stack per copy to each, read
# `effect_scene_condition[i]` for effect i and pop one stack from each on
# remove. These suites pin that contract.
class_name ItemHolderMultiEffectsTest
extends GdUnitTestSuite

const ARMOR_SCENE := "res://src/Systems/Items/modifiers/ArmorModifier.tscn"
const LIFE_LEACH_SCENE := "res://src/Systems/Items/modifiers/LifeLeachModifier.tscn"


func _build_holder() -> Node:
    var holder := Node.new()
    holder.name = "Holder"
    var event_manager := EventManager.new()
    event_manager.name = "EventManager"
    holder.add_child(event_manager)
    var stats := Stats.new()
    stats.name = "Stats"
    stats.event_manager = event_manager
    holder.add_child(stats)
    var item_holder := ItemHolder.new()
    item_holder.name = "ItemHolder"
    holder.add_child(item_holder)
    add_child(holder)
    return holder


func _multi_effect_item(effect_scenes: Array[PackedScene], modifiers: Dictionary = {}) -> Item:
    var item := ItemBuilder.make_effect_item("Two effect item", "Two effects", effect_scenes[0], modifiers)
    item.effect_scene = effect_scenes
    return item


func _effect_node(holder: Node, scene_path: String) -> BaseModifier:
    for child in holder.get_node("ItemHolder").get_children():
        if child.scene_file_path == scene_path:
            return child as BaseModifier
    return null


# Records the failure and returns null instead of letting the caller dereference
# a missing node, which would abort the whole run on a debugger break.
func _expect_effect_node(holder: Node, scene_path: String) -> BaseModifier:
    var effect := _effect_node(holder, scene_path)
    assert_that(effect).is_not_null()
    return effect


func _effect_node_count(holder: Node, scene_path: String) -> int:
    var count := 0
    for child in holder.get_node("ItemHolder").get_children():
        if child.scene_file_path == scene_path:
            count += 1
    return count


func test_every_effect_scene_gets_its_own_node() -> void:
    var holder := _build_holder()

    holder.get_node("ItemHolder").add_item(_multi_effect_item([load(ARMOR_SCENE), load(LIFE_LEACH_SCENE)]))

    var armor := _expect_effect_node(holder, ARMOR_SCENE)
    var life_leach := _expect_effect_node(holder, LIFE_LEACH_SCENE)
    if armor == null or life_leach == null:
        holder.free()
        return
    assert_that(armor).is_not_same(life_leach)
    # both are live nodes of the ItemHolder, not orphaned copies
    assert_that(armor.get_parent()).is_same(holder.get_node("ItemHolder"))
    assert_that(life_leach.get_parent()).is_same(holder.get_node("ItemHolder"))
    # every effect is wired to the EventManager, not just the first one
    assert_that(armor.event_manager).is_not_null()
    assert_that(life_leach.event_manager).is_not_null()
    assert_int(armor.stacks.size()).is_equal(1)
    assert_int(life_leach.stacks.size()).is_equal(1)

    holder.free()


func test_each_effect_gets_one_stack_per_copy() -> void:
    var holder := _build_holder()
    var item_holder: ItemHolder = holder.get_node("ItemHolder")
    var item := _multi_effect_item([load(ARMOR_SCENE), load(LIFE_LEACH_SCENE)])

    item_holder.add_item(item)
    var first_armor := _expect_effect_node(holder, ARMOR_SCENE)
    var first_life_leach := _expect_effect_node(holder, LIFE_LEACH_SCENE)
    if first_armor == null or first_life_leach == null:
        holder.free()
        return
    assert_int(first_armor.stacks.size()).is_equal(1)
    assert_int(first_life_leach.stacks.size()).is_equal(1)

    item_holder.add_item(item)

    # deduplication still holds: one node per scene, not one per copy
    assert_int(_effect_node_count(holder, ARMOR_SCENE)).is_equal(1)
    assert_int(_effect_node_count(holder, LIFE_LEACH_SCENE)).is_equal(1)
    var armor := _expect_effect_node(holder, ARMOR_SCENE)
    var life_leach := _expect_effect_node(holder, LIFE_LEACH_SCENE)
    if armor == null or life_leach == null:
        holder.free()
        return
    assert_int(armor.stacks.size()).is_equal(2)
    assert_int(life_leach.stacks.size()).is_equal(2)

    holder.free()


func test_stat_modifiers_are_applied_once_not_once_per_effect() -> void:
    var holder := _build_holder()
    var stats: Stats = holder.get_node("Stats")

    holder.get_node("ItemHolder").add_item(
        _multi_effect_item([load(ARMOR_SCENE), load(LIFE_LEACH_SCENE)], {"damage": {"flat": 5.0}})
    )

    assert_int(stats.modifiers.size()).is_equal(1)
    assert_float(stats.get_stat("damage")).is_equal_approx(6.0, 0.001)

    holder.free()


func test_condition_is_matched_to_its_own_effect_index() -> void:
    var holder := _build_holder()
    var stats: Stats = holder.get_node("Stats")
    var item := _multi_effect_item([load(ARMOR_SCENE), load(LIFE_LEACH_SCENE)])
    item.effect_scene_condition = ["", "poisoned"]

    holder.get_node("ItemHolder").add_item(item)

    var armor := _expect_effect_node(holder, ARMOR_SCENE)
    var life_leach := _expect_effect_node(holder, LIFE_LEACH_SCENE)
    if armor == null or life_leach == null:
        holder.free()
        return
    # "poisoned" is 0, so only the second effect starts with an inactive stack
    assert_bool(armor.stacks[0]).is_true()
    assert_bool(life_leach.stacks[0]).is_false()

    stats.set_condition("poisoned", 1.0)

    # the condition only wakes the effect it was declared for
    assert_bool(armor.stacks[0]).is_true()
    assert_bool(life_leach.stacks[0]).is_true()

    holder.free()


func test_removing_the_item_pops_one_stack_from_every_effect() -> void:
    var holder := _build_holder()
    var item_holder: ItemHolder = holder.get_node("ItemHolder")
    var item := _multi_effect_item([load(ARMOR_SCENE), load(LIFE_LEACH_SCENE)])
    item_holder.add_item(item)
    item_holder.add_item(item)
    var armor := _expect_effect_node(holder, ARMOR_SCENE)
    var life_leach := _expect_effect_node(holder, LIFE_LEACH_SCENE)
    if armor == null or life_leach == null:
        holder.free()
        return

    item_holder.remove_item(item)

    assert_int(armor.stacks.size()).is_equal(1)
    assert_int(life_leach.stacks.size()).is_equal(1)

    item_holder.remove_item(item)

    # last copy gone: both effect nodes are released
    assert_bool(armor.is_queued_for_deletion()).is_true()
    assert_bool(life_leach.is_queued_for_deletion()).is_true()

    holder.free()
