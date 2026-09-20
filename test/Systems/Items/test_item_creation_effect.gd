# GdUnit generated TestSuite
class_name ItemCreationEffectTest
extends GdUnitTestSuite

func test_stat_creation_effect() -> void:
    var factory : ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
    add_child(factory)
    # var item = factory.get_item_by_type("effect")
    var item: Item = _create_item("ProjectileBounceModifier.tscn", 1)
    assert_object(item).is_not_null()
    collect_orphan_node_details()

func _create_item(modifier_name: String, amount: float) -> Item:
    var modifier_scene: PackedScene = load("res://src/Systems/Items/Modifiers/" + modifier_name)
    return ItemBuilder.make_effect_item(
        "Buff_%s_%s" % [modifier_name, str(amount)],
        "Buff: +%s %s" % [amount, modifier_name],
        modifier_scene
    )