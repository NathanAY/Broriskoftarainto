# GdUnit TestSuite guarding the offerable pool itself.
#
# `ItemFactory._ready` loads every `.tscn` in `src/Systems/Items/modifiers` by
# directory scan, so ANY scene dropped in that folder becomes something the shop
# can roll - including a base class that was only ever meant to be `extends`-ed.
# These tests pin that pool down: nothing in it may be behaviourless.
class_name OfferableModifierScenesTest
extends GdUnitTestSuite

const MODIFIERS_DIR := "res://src/Systems/Items/modifiers"


## Every regen-shaped scene in the folder must move health by a non-zero amount
## per tick.
##
## `regen_modifier.gd` is an abstract base: it owns the timer, the tick and the
## stack scaling, but its `_health_delta_per_tick` returns 0.0 for subclasses to
## override. As a scene it therefore healed nothing while still rendering as a
## plain gold BENEFIT card named "Regen" with no stats fragment - a price-3 item
## that did nothing. Asserting the mechanism rather than the file name means a
## future abstract base dropped here fails the same way.
func test_no_offerable_regen_scene_heals_nothing() -> void:
    var scenes: Array[PackedScene] = ItemBuilder.load_scenes_from_dir(MODIFIERS_DIR)
    assert_bool(scenes.is_empty()).override_failure_message(
        "no scenes found in %s - the folder path is what this suite guards" % MODIFIERS_DIR
    ).is_false()

    # Health.max_health defaults to 50, which is all the percent variant reads.
    var probe := Health.new()
    var checked := 0
    for scene in scenes:
        var instance: Node = scene.instantiate()
        if instance != null and instance.has_method("_health_delta_per_tick"):
            var delta: float = float(instance.call("_health_delta_per_tick", probe))
            assert_float(absf(delta)).override_failure_message(
                "%s is in the offerable pool but heals 0 HP per tick - it is an abstract "
                % scene.resource_path.get_file() + "base that was never meant to be instantiated"
            ).is_greater(0.0)
            checked += 1
        if instance != null:
            instance.free()
    assert_int(checked).override_failure_message(
        "no regen-shaped scene was found - the detection below is broken"
    ).is_greater(0)
    probe.free()


## The abstract regen base must not exist as a scene at all. `regen_modifier.gd`
## is referenced by path from its subclasses, so removing the scene costs the
## hierarchy nothing while taking the behaviourless item out of the pool.
func test_the_abstract_regen_base_is_not_an_offerable_scene() -> void:
    assert_bool(FileAccess.file_exists("%s/RegenModifier.tscn" % MODIFIERS_DIR)).override_failure_message(
        "RegenModifier.tscn is the behaviourless regen_modifier.gd base; it is picked up by "
        + "ItemFactory's directory scan and sold as a do-nothing item. Delete the scene - the "
        + "script stays, its subclasses extend it by path."
    ).is_false()
