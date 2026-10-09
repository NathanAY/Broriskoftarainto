# GdUnit TestSuite pinning the project's single meter/pixel contract.
#
# `Stats.PIXELS_PER_METER` is the one place the world scale lives, and every
# designer-facing distance - a weapon's `weapon_range`, a knockback strength,
# an explosion / bounce / homing / orbit radius - is authored in meters and
# converted only where it meets the physics server, a target selector or a
# `Vector2`. These suites pin both halves: the stored value is a small meter
# number, and the pixel accessor it feeds is exactly `meters * 300`.
#
# They exist because a mixed-units bug is invisible: a `.tres` that still
# declares `range = 300` (px) simply reads as 300 meters once the field is
# meter-typed, and no damage test notices until the weapon one-shots the arena.
# See `docs/systems/stats.md`, "Units".
class_name UnitConversionsTest
extends GdUnitTestSuite

const FIST := "res://src/Resources/weapons/Fist.tres"
const PISTOL := "res://src/Resources/weapons/Pistol.tres"
const DEATH_AURA := "res://src/Resources/weapons/DeathAura.tres"
const ORB_SCENE := "res://src/Scenes/OrbitingOrb.tscn"

const KNOCKBACK_MODIFIER := preload("res://src/Systems/Items/modifiers/knockback_modifier.gd")
const HOMING_MODIFIER := preload("res://src/Systems/Items/modifiers/homing_modifier.gd")
const HOMING_BEHAVIOR := preload("res://src/Systems/weapon/homing_behavior.gd")
const HOMING_ROCKET := preload("res://src/Systems/Items/modifiers/homing_rocket_modifier.gd")
const BOUNCE_MODIFIER := preload("res://src/Systems/Items/modifiers/projectile_bounce_modifier.gd")
const CHAIN_MODIFIER := preload("res://src/Systems/Items/modifiers/chain_modifier.gd")
const SPINNING_ORBS_PATH := "res://src/Systems/Items/modifiers/spinning_orbs_modifier.gd"

## Tolerance for the 2-decimal meter literals: 1.33 m is 399 px, not 400.
const METER_TOLERANCE := 0.01


# --- the scale itself ---------------------------------------------------------

func test_pixels_per_meter_is_300() -> void:
	assert_float(Stats.PIXELS_PER_METER).is_equal(300.0)


func test_meters_to_px_and_back_round_trip() -> void:
	assert_float(Stats.meters_to_px(1.0)).is_equal(300.0)
	assert_float(Stats.meters_to_px(0.5)).is_equal(150.0)
	assert_float(Stats.px_to_meters(300.0)).is_equal(1.0)
	assert_float(Stats.px_to_meters(Stats.meters_to_px(1.33))).is_equal_approx(1.33, 0.0001)


# --- weapon range -------------------------------------------------------------

func test_weapon_range_default_is_authored_in_meters() -> void:
	var weapon := BaseWeapon.new()
	# A small meter number, not the old 400-pixel literal.
	assert_float(weapon.weapon_range).is_equal_approx(1.33, METER_TOLERANCE)
	assert_float(weapon.get_range_px()).is_equal_approx(
		Stats.meters_to_px(weapon.weapon_range), 0.0001)


func test_fist_range_is_one_meter() -> void:
	var fist: BaseWeapon = load(FIST)
	assert_float(fist.weapon_range).override_failure_message(
		"Fist.tres must author its range in meters (300 px = 1.0 m)").is_equal(1.0)
	assert_float(fist.get_range_px()).is_equal(300.0)


func test_death_aura_radius_is_half_its_range_in_meters() -> void:
	var aura: AreaWeapon = load(DEATH_AURA)
	assert_float(aura.radius).is_equal_approx(aura.weapon_range * 0.5, 0.0001)
	assert_float(aura.get_radius_px()).is_equal_approx(
		Stats.meters_to_px(aura.weapon_range) * 0.5, 0.0001)


# --- knockback (m/s) ----------------------------------------------------------

func test_weapon_knockback_strengths_are_meters_per_second() -> void:
	var fist: BaseWeapon = load(FIST)
	var pistol: BaseWeapon = load(PISTOL)
	assert_float(fist.modifiers["knockback"]["strength"]).is_equal_approx(0.83, METER_TOLERANCE)
	assert_float(pistol.modifiers["knockback"]["strength"]).is_equal_approx(0.4, METER_TOLERANCE)


func test_knockback_modifier_and_behavior_default_to_one_meter_per_second() -> void:
	var modifier = KNOCKBACK_MODIFIER.new()
	var behavior := KnockbackBehavior.new()
	assert_float(modifier.knockback_strength).is_equal(1.0)
	assert_float(behavior.knockback_strength).is_equal(1.0)
	modifier.free()
	behavior.free()


func test_knockback_controller_converts_meters_to_pixels() -> void:
	var controller := KnockbackController.new()
	controller.start_knockback(Vector2.RIGHT * 1.0, 0.2)
	assert_float(controller.knockback_velocity.length()).override_failure_message(
		"1 m/s must reach the physics step as 300 px/s").is_equal(300.0)
	# the Fist's authored strength, 0.83 m/s -> 249 px/s
	controller.start_knockback(Vector2.RIGHT * 0.83, 0.2)
	assert_float(controller.knockback_velocity.length()).is_equal_approx(249.0, 0.5)
	controller.free()


# --- explosion / bounce / homing / orbit radii --------------------------------

func test_explosion_radius_is_authored_in_meters() -> void:
	var explosion := _make_explosion()
	explosion.radius = 1.0
	add_child(explosion)
	var shape := explosion.get_node("CollisionShape2D").shape as CircleShape2D
	assert_float(shape.radius).override_failure_message(
		"the collision radius must be the meter value converted to pixels").is_equal(300.0)
	explosion.free()


func test_explosion_radius_scales_by_area_size_multiplier_in_pixels() -> void:
	var holder := Node.new()
	var em := EventManager.new()
	em.name = "EventManager"
	holder.add_child(em)
	var stats := Stats.new()
	stats.name = "Stats"
	stats.event_manager = em
	holder.add_child(stats)
	stats.set_base_stat("area_size_multiplier", 2.0)
	add_child(holder)

	var explosion := _make_explosion()
	explosion.stats = stats
	explosion.radius = 0.5
	holder.add_child(explosion)
	var shape := explosion.get_node("CollisionShape2D").shape as CircleShape2D
	# 0.5 m * 2.0 = 1.0 m = 300 px
	assert_float(shape.radius).is_equal(300.0)
	holder.free()


## An `Explosion` with the one child `_ready` requires. Built by hand rather
## than from the scene so the test is not coupled to whatever else
## `Explosion.tscn` happens to instance.
func _make_explosion() -> Explosion:
	var explosion := Explosion.new()
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	shape.shape = CircleShape2D.new()
	explosion.add_child(shape)
	return explosion


func test_orbiting_orb_places_itself_with_a_meter_radius() -> void:
	var orb: SpinningOrb = load(ORB_SCENE).instantiate()
	var center := Node2D.new()
	add_child(center)
	orb.orbit_center = center
	orb.orbit_radius = 0.3
	orb.orbit_speed = 0.0
	orb.angle_offset = 0.0
	add_child(orb)

	orb._process(0.016)

	# 0.3 m = 90 px, and orbit_speed 0 freezes the angle at the 0 offset.
	assert_float(orb.global_position.x).is_equal_approx(center.global_position.x + 90.0, 0.001)
	assert_float(orb.global_position.y).is_equal_approx(center.global_position.y, 0.001)
	center.free()


func test_spinning_orb_and_its_modifier_authored_radius_in_meters() -> void:
	var orb: SpinningOrb = load(ORB_SCENE).instantiate()
	assert_float(orb.orbit_radius).is_equal_approx(0.2, METER_TOLERANCE)
	orb.free()
	# The spawned orbs get the modifier's own radius, 0.3 m. Read through the
	# loaded script (a GDScript resource) rather than the class, which cannot
	# expose a constant map directly.
	var script := load(SPINNING_ORBS_PATH) as GDScript
	var constants: Dictionary = script.get_script_constant_map()
	var orbit_radius: float = constants["ORBIT_RADIUS"]
	assert_float(orbit_radius).is_equal_approx(0.3, METER_TOLERANCE)


func test_weapon_holder_orbit_radius_is_meters() -> void:
	var holder := WeaponHolder.new()
	assert_float(holder.weapon_orbit_radius).is_equal_approx(0.2, METER_TOLERANCE)
	# angle_offset -PI puts a single weapon due left, 0.2 m = 60 px away.
	assert_float(holder._get_weapon_position(0, 1).x).is_equal_approx(-60.0, 0.001)
	holder.free()


func test_homing_and_bounce_ranges_are_meters() -> void:
	var homing = HOMING_MODIFIER.new()
	var homing_behavior = HOMING_BEHAVIOR.new()
	var homing_rocket = HOMING_ROCKET.new()
	var bounce = BOUNCE_MODIFIER.new()
	var chain = CHAIN_MODIFIER.new()
	var homing_range: float = homing.homing_range
	var behavior_range: float = homing_behavior.homing_range
	var rocket_range: float = homing_rocket.homing_range
	var bounce_range: float = bounce.bounce_range
	var chain_range: float = chain.bounce_range
	assert_float(homing_range).is_equal_approx(1.33, METER_TOLERANCE)
	assert_float(behavior_range).is_equal_approx(1.33, METER_TOLERANCE)
	assert_float(rocket_range).is_equal_approx(2.0, METER_TOLERANCE)
	assert_float(bounce_range).is_equal_approx(3.33, METER_TOLERANCE)
	assert_float(chain_range).is_equal_approx(3.33, METER_TOLERANCE)
	homing.free()
	homing_behavior.free()
	homing_rocket.free()
	bounce.free()
	chain.free()
