# GdUnit TestSuite for movement_speed unit conversion (m/s <-> px/s).
class_name MovementSpeedUnitsTest
extends GdUnitTestSuite

const PIXELS_PER_METER: float = 200.0


func _build_stats() -> Stats:
    var holder := Node.new()
    holder.name = "Holder"
    var event_manager := EventManager.new()
    event_manager.name = "EventManager"
    holder.add_child(event_manager)
    var stats := Stats.new()
    stats.name = "Stats"
    stats.event_manager = event_manager
    holder.add_child(stats)
    add_child(holder)
    return stats


func test_default_movement_speed_is_meters_per_second() -> void:
    var stats := _build_stats()
    assert_float(stats.get_stat("movement_speed")).is_equal_approx(0.25, 0.0001)
    assert_float(stats.get_movement_speed_px()).is_equal_approx(50.0, 0.0001)
    stats.get_parent().free()


func test_one_meter_per_second_maps_to_200_px() -> void:
    var stats := _build_stats()
    stats.set_base_stat("movement_speed", 1.0)
    assert_float(stats.get_stat("movement_speed")).is_equal_approx(1.0, 0.0001)
    assert_float(stats.get_movement_speed_px()).is_equal_approx(PIXELS_PER_METER, 0.0001)
    stats.get_parent().free()


func test_flat_and_percent_modifiers_apply_in_meters() -> void:
    var stats := _build_stats()
    stats.add_modifier({"movement_speed": {"flat": 0.5, "percent": 1.0}})
    assert_float(stats.get_stat("movement_speed")).is_equal_approx(1.5, 0.0001)
    assert_float(stats.get_movement_speed_px()).is_equal_approx(300.0, 0.0001)
    stats.get_parent().free()


func test_boots_of_speed_flat_is_one_meter_per_second() -> void:
    var boots: Resource = load("res://src/Resources/items/BootsOfSpeed.tres")
    assert_object(boots).is_not_null()
    var flat: Variant = boots.get("modifiers")["movement_speed"]["flat"]
    assert_float(float(flat)).is_equal_approx(1.0, 0.0001)


func test_character_base_stats_are_in_meters_per_second() -> void:
    for path in [
        "res://src/Assets/character/wildling/Wildling.tres",
        "res://src/Assets/character/soldier/Soldier.tres",
        "res://src/Assets/character/ranger/Ranger.tres",
        "res://src/Assets/character/multitasker/Multitasker.tres",
    ]:
        var character: Resource = load(path)
        assert_float(float(character.get("base_stats")["movement_speed"])).is_less(1.0)