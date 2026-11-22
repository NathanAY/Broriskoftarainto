# GdUnit TestSuite for `Damage.deal()`, the one entry point every damage source
# uses, and the rules it owns: crit, armor, listener phases, and which hits
# count as a direct hit (`on_hit`).
class_name DamagePipelineTest
extends GdUnitTestSuite

const PISTOL := "res://src/Resources/weapons/Pistol.tres"
const BIG_HEALTH := 1000.0

var _log: Array[String] = []


## An entity the way every scene builds one: EventManager, Stats and Health
## siblings under one node.
func _entity(entity_name: String) -> Node2D:
	var entity := Node2D.new()
	entity.name = entity_name
	var bus := EventManager.new()
	bus.name = "EventManager"
	entity.add_child(bus)
	var stats := Stats.new()
	stats.name = "Stats"
	stats.event_manager = bus
	entity.add_child(stats)
	var health := Health.new()
	health.name = "Health"
	health.event_manager = bus
	entity.add_child(health)
	auto_free(entity)
	add_child(entity)
	stats.set_base_stat("health", BIG_HEALTH)
	health.current_health = BIG_HEALTH
	return entity


func _bus(entity: Node) -> EventManager:
	return entity.get_node("EventManager")


func _stats(entity: Node) -> Stats:
	return entity.get_node("Stats")


func _health(entity: Node) -> Health:
	return entity.get_node("Health")


func _record(bus: EventManager, events: Array, prefix: String) -> void:
	for event_name in events:
		bus.subscribe(event_name, func(_e): _log.append(prefix + event_name))


func _hit(target: Node, amount: float, weapon: BaseWeapon = null) -> DamageContext:
	var ctx := DamageContext.new()
	ctx.target = target
	ctx.base_amount = amount
	ctx.final_amount = amount
	ctx.weapon = weapon
	return ctx


func before_test() -> void:
	_log.clear()


# ---------------- order and direct hits ----------------

func test_events_run_in_pipeline_order() -> void:
	var attacker := _entity("Attacker")
	var target := _entity("Target")
	_stats(attacker).set_base_stat("critical_chance", 100.0)
	_record(_bus(attacker), ["before_deal_damage", "on_crit", "after_deal_damage", "on_hit", "on_kill"], "a:")
	_record(_bus(target), ["before_take_damage", "after_take_damage", "on_death"], "t:")

	var ctx := _hit(target, BIG_HEALTH * 10.0, BaseWeapon.new())
	assert_bool(Damage.deal(ctx, _bus(attacker))).is_true()

	assert_array(_log).is_equal([
		"a:before_deal_damage", "a:on_crit",
		"t:before_take_damage", "t:on_death", "t:after_take_damage",
		"a:after_deal_damage", "a:on_hit", "a:on_kill"])
	assert_object(ctx.attacker).is_same(attacker)


func test_hit_without_a_weapon_is_not_a_direct_hit() -> void:
	var attacker := _entity("Attacker")
	var target := _entity("Target")
	_record(_bus(attacker), ["after_deal_damage", "on_hit", "on_kill"], "")

	Damage.deal(_hit(target, BIG_HEALTH * 10.0), _bus(attacker))

	# An explosion, orb or poison tick still reports damage and kills, but never
	# procs on-hit effects, so secondary damage cannot chain into more of itself.
	assert_array(_log).is_equal(["after_deal_damage", "on_kill"])


func test_dead_target_is_rejected_silently() -> void:
	var attacker := _entity("Attacker")
	var target := _entity("Target")
	Damage.deal(_hit(target, BIG_HEALTH * 10.0, BaseWeapon.new()), _bus(attacker))
	_log.clear()
	_record(_bus(attacker), ["after_deal_damage", "on_hit", "on_kill"], "")

	assert_bool(Damage.deal(_hit(target, 5.0, BaseWeapon.new()), _bus(attacker))).is_false()
	assert_array(_log).is_empty()


# ---------------- crit ----------------

## 100 is the top of the 0-100 scale, so every hit crits: a property of the
## scale, not a balance value.
func test_full_crit_chance_multiplies_by_the_crit_multiplier() -> void:
	var attacker := _entity("Attacker")
	var target := _entity("Target")
	_stats(attacker).set_base_stat("critical_chance", 100.0)
	_stats(attacker).add_modifier({"critical_multiplier": {"flat": 1.0}})

	var ctx := _hit(target, 10.0)
	Damage.deal(ctx, _bus(attacker))

	assert_bool(ctx.is_crit).is_true()
	assert_float(ctx.final_amount).is_equal_approx(10.0 * _stats(attacker).get_stat("critical_multiplier"), 0.001)


func test_zero_crit_chance_never_crits() -> void:
	var attacker := _entity("Attacker")
	var target := _entity("Target")
	for i in 50:
		var ctx := _hit(target, 1.0)
		Damage.deal(ctx, _bus(attacker))
		assert_bool(ctx.is_crit).is_false()


func test_damage_that_cannot_crit_never_crits() -> void:
	var attacker := _entity("Attacker")
	var target := _entity("Target")
	_stats(attacker).set_base_stat("critical_chance", 100.0)
	var ctx := _hit(target, 10.0)
	ctx.can_crit = false
	Damage.deal(ctx, _bus(attacker))
	assert_bool(ctx.is_crit).is_false()
	assert_float(ctx.final_amount).is_equal(10.0)


func test_poison_ticks_do_not_crit() -> void:
	var attacker := _entity("Attacker")
	var target := _entity("Target")
	_stats(attacker).set_base_stat("critical_chance", 100.0)
	var crits: Array = []
	_bus(attacker).subscribe("on_crit", func(e): crits.append(e))

	var poison := PoisonEffect.new()
	_health(target).add_child(poison)
	poison.start_effect(_health(target), 5.0, 10.0, 1.0, 10, attacker)
	poison._on_tick()

	assert_float(_health(target).current_health).is_less(BIG_HEALTH)
	assert_array(crits).is_empty()


# ---------------- armor ----------------

func test_target_armor_stat_reduces_damage_without_any_item() -> void:
	var attacker := _entity("Attacker")
	var target := _entity("Target")
	_stats(target).set_base_stat("armor", 10.0)

	var ctx := _hit(target, 20.0)
	Damage.deal(ctx, _bus(attacker))

	assert_float(ctx.final_amount).is_equal_approx(20.0 * Damage.armor_multiplier(10.0), 0.001)
	assert_float(ctx.final_amount).is_less(20.0)


func test_armor_multiplier_shape() -> void:
	assert_float(Damage.armor_multiplier(0.0)).is_equal(1.0)
	assert_float(Damage.armor_multiplier(10.0)).is_less(1.0)
	assert_float(Damage.armor_multiplier(20.0)).is_less(Damage.armor_multiplier(10.0))
	assert_float(Damage.armor_multiplier(-5.0)).is_greater(1.0)


## Several armor sources live in the one stat, so a hit is reduced once.
func test_two_armor_items_reduce_once_by_the_summed_stat() -> void:
	var attacker := _entity("Attacker")
	var target := _entity("Target")
	_stats(target).add_modifier({"armor": {"flat": 4.0}})
	_stats(target).add_modifier({"armor": {"flat": 6.0}})

	var ctx := _hit(target, 20.0)
	Damage.deal(ctx, _bus(attacker))

	assert_float(ctx.final_amount).is_equal_approx(20.0 * Damage.armor_multiplier(10.0), 0.001)


# ---------------- listener phases ----------------

func test_listeners_run_by_phase_not_by_subscription_order() -> void:
	var bus := EventManager.new()
	auto_free(bus)
	bus.subscribe("on_hit", func(_e): _log.append("observe"), Damage.PHASE_OBSERVE)
	bus.subscribe("on_hit", func(_e): _log.append("absorb"), Damage.PHASE_ABSORB)
	bus.subscribe("on_hit", func(_e): _log.append("modify"))
	bus.subscribe("on_hit", func(_e): _log.append("mitigate"), Damage.PHASE_MITIGATE)
	bus.subscribe("on_hit", func(_e): _log.append("modify2"))

	bus.emit_event("on_hit", {"damage_context": DamageContext.new()})

	assert_array(_log).is_equal(["modify", "modify2", "mitigate", "absorb", "observe"])


func test_unsubscribe_keeps_phases_aligned() -> void:
	var bus := EventManager.new()
	auto_free(bus)
	var first := func(_e): _log.append("first")
	bus.subscribe("on_hit", first, Damage.PHASE_MITIGATE)
	bus.subscribe("on_hit", func(_e): _log.append("late"), Damage.PHASE_OBSERVE)
	bus.unsubscribe("on_hit", first)
	bus.subscribe("on_hit", func(_e): _log.append("early"))

	bus.emit_event("on_hit", {"damage_context": DamageContext.new()})

	assert_array(_log).is_equal(["early", "late"])


# ---------------- end to end ----------------

## The real player and a real weapon, with no crit item anywhere.
func test_player_crits_from_stat_alone() -> void:
	var runner := scene_runner(WeaponTestSupport.TEST_SCENE)
	var test_scene := runner.scene()
	runner.set_time_factor(5)
	get_tree().current_scene = test_scene

	var enemy: Enemy = test_scene.get_node("Enemy")
	var e_health := WeaponTestSupport.give_enemy_health(enemy)
	var character: Character = test_scene.get_node("Character")
	WeaponTestSupport.equip_only_weapon(character, PISTOL)
	character.stats.set_base_stat("critical_chance", 100.0)
	var crits: Array = []
	character.event_manager.subscribe("on_crit", func(e): crits.append(e))

	@warning_ignore("redundant_await")
	await runner.simulate_frames(WeaponTestSupport.FRAMES)

	assert_float(WeaponTestSupport.health_left(e_health)).is_less(WeaponTestSupport.ENEMY_HEALTH)
	assert_bool(crits.is_empty()).override_failure_message(
		"a hit landed with 100% critical_chance but did not crit").is_false()
	test_scene.free()
