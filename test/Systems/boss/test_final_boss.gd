# The final boss (the Vault Baron): its phases, its attack picker, its coin
# patterns and its attacks. See docs/systems/final_boss.md.
#
# The boss's own physics process is switched off, so each test drives the
# brain by hand with `process_movement()` and nothing else moves the boss.
# Every number is read from `game_config.json` (`final_boss`), never pinned.
class_name FinalBossTest
extends GdUnitTestSuite

const BOSS_SCENE := "res://src/Systems/enemies/EnemyFinalBoss.tscn"
const STEP := 1.0 / 60.0

var _root: Node2D = null
var _coins: Array = []


func after_test() -> void:
    # The boss's death slows time; never leak that into the next test.
    Engine.time_scale = 1.0
    for coin in _coins:
        if is_instance_valid(coin):
            coin.free()
    _coins.clear()
    if is_instance_valid(_root):
        _root.free()


func _make_boss() -> Dictionary:
    _root = Node2D.new()
    _root.name = "World"
    add_child(_root)
    var boss: Enemy = load(BOSS_SCENE).instantiate()
    _root.add_child(boss)
    boss.set_physics_process(false)
    boss.global_position = Vector2.ZERO
    var target := Node2D.new()
    _root.add_child(target)
    target.global_position = Vector2(300, 0)
    boss.set_target_position(target)
    return {"boss": boss, "brain": boss.behaviour as BossBrain, "target": target}


func _config() -> Dictionary:
    return BossBrain.config()


func _threshold(index: int) -> float:
    return float(_config().get("phase_thresholds", [0.65, 0.30])[index])


## Hits the boss from behind (the shield only guards the front) and returns the
## health it lost.
func _hit(boss: Enemy, amount: float) -> float:
    var source := Node2D.new()
    _root.add_child(source)
    source.global_position = boss.global_position + Vector2(-200, 0)
    boss.sprite.flip_h = false
    var health := boss.health_node
    var before_hit := health.current_health
    var ctx := DamageContext.new()
    ctx.source = source
    ctx.target = boss
    ctx.base_amount = amount
    ctx.final_amount = amount
    health.apply_damage(ctx)
    source.free()
    return before_hit - health.current_health


## Runs the brain until it is out of its phase transition.
func _finish_transition(brain: BossBrain, boss: Enemy) -> void:
    var guard := 0
    while brain.is_transitioning() and guard < 10000:
        brain.process_movement(boss, STEP)
        guard += 1


## Takes the boss into `phase` the way the game does: damage, then transition.
func _reach_phase(ctx: Dictionary, target_phase: int) -> void:
    var boss: Enemy = ctx["boss"]
    var brain: BossBrain = ctx["brain"]
    while brain.phase < target_phase:
        _hit(boss, boss.health_node.max_health)
        _finish_transition(brain, boss)


## Runs one attack to the end and returns how many ticks it took.
func _run_attack(attack: BossAttack, boss: Enemy, target: Node2D) -> int:
    attack.start(boss, target)
    var ticks := 0
    while not attack.tick(STEP) and ticks < 10000:
        ticks += 1
    return ticks


func _track(coins: Array) -> Array:
    _coins.append_array(coins)
    return coins


# --- phases -------------------------------------------------------------------

func test_crossing_a_threshold_starts_a_transition_into_the_next_phase() -> void:
    var ctx := _make_boss()
    var boss: Enemy = ctx["boss"]
    var brain: BossBrain = ctx["brain"]
    var max_hp := boss.health_node.max_health
    assert_int(brain.phase).is_equal(1)

    # Just above the threshold: still phase 1, no transition.
    _hit(boss, max_hp * (1.0 - _threshold(0)) * 0.9)
    assert_bool(brain.is_transitioning()).is_false()

    _hit(boss, max_hp)
    assert_bool(brain.is_transitioning()).is_true()
    assert_int(brain.phase).is_equal(1)
    _finish_transition(brain, boss)
    assert_int(brain.phase).is_equal(2)


func test_one_huge_hit_cannot_skip_a_phase() -> void:
    var ctx := _make_boss()
    var boss: Enemy = ctx["boss"]
    var max_hp := boss.health_node.max_health

    _hit(boss, max_hp * 100.0)

    assert_bool(boss.health_node.is_dead).override_failure_message(
        "a burst killed the boss straight out of phase 1").is_false()
    assert_float(boss.health_node.current_health).is_equal_approx(max_hp * _threshold(0), 0.001)


func test_the_boss_takes_no_damage_while_it_transitions() -> void:
    var ctx := _make_boss()
    var boss: Enemy = ctx["boss"]
    _hit(boss, boss.health_node.max_health)
    assert_bool((ctx["brain"] as BossBrain).is_transitioning()).is_true()

    assert_float(_hit(boss, 1.0)).is_equal(0.0)


func test_phase_three_breaks_the_shield_and_swaps_the_art() -> void:
    var ctx := _make_boss()
    var boss: Enemy = ctx["boss"]
    var brain: BossBrain = ctx["brain"]
    var shield := boss.get_node("FrontShield")

    _reach_phase(ctx, 2)
    assert_bool(shield.is_queued_for_deletion()).is_false()
    _reach_phase(ctx, 3)

    assert_bool(shield.is_queued_for_deletion()).is_true()
    assert_object(boss.sprite.texture).is_same(brain.broken_texture)


func test_phase_three_takes_more_damage_than_phase_two() -> void:
    var ctx := _make_boss()
    var boss: Enemy = ctx["boss"]
    _reach_phase(ctx, 2)
    var small := boss.health_node.max_health * 0.01
    var lost_in_two := _hit(boss, small)
    _reach_phase(ctx, 3)

    var lost_in_three := _hit(boss, small)

    assert_float(lost_in_three).is_equal_approx(
        lost_in_two * float(_config().get("phase3_damage_taken_mult", 1.0)), 0.0001)


func test_phase_speed_comes_from_the_config() -> void:
    var ctx := _make_boss()
    var boss: Enemy = ctx["boss"]
    var speed_in_one := boss.stats.get_stat("movement_speed")
    var mults: Array = _config().get("speed_mult", [1.0, 1.0, 1.0])
    _reach_phase(ctx, 3)

    assert_float(boss.stats.get_stat("movement_speed")).is_equal_approx(
        speed_in_one * float(mults[2]) / float(mults[0]), 0.0001)


# --- picker -------------------------------------------------------------------

func test_the_picker_never_repeats_the_last_attack() -> void:
    var ctx := _make_boss()
    var brain: BossBrain = ctx["brain"]
    brain.rng.seed = 7
    assert_int(brain.attacks().size()).is_greater(1)
    for i in 200:
        var picked := brain.pick_attack()
        assert_object(picked).is_not_same(brain.last_attack)
        brain.last_attack = picked


func test_the_picker_only_offers_attacks_allowed_in_the_phase() -> void:
    var ctx := _make_boss()
    var brain: BossBrain = ctx["brain"]
    brain.rng.seed = 11
    for phase in [1, 2, 3]:
        brain.phase = phase
        for i in 50:
            assert_bool(brain.pick_attack().allowed_in(phase)).is_true()


func test_the_brain_starts_attacking_after_the_intro() -> void:
    var ctx := _make_boss()
    var boss: Enemy = ctx["boss"]
    var brain: BossBrain = ctx["brain"]
    var intro := float(_config().get("intro_time", 1.5))
    var ticks := 0
    while brain.current_attack == null and ticks < 10000:
        brain.process_movement(boss, STEP)
        ticks += 1
    assert_object(brain.current_attack).is_not_null()
    assert_float(ticks * STEP).is_greater_equal(intro - STEP)
    brain.current_attack.stop()


# --- coin patterns ------------------------------------------------------------

func test_a_fan_is_centred_on_its_aim() -> void:
    var boss: Enemy = _make_boss()["boss"]
    var aim := Vector2(1, 1).normalized()

    var coins := _track(BossBullets.fan(boss, aim, 7, 60.0))

    assert_int(coins.size()).is_equal(7)
    var sum := Vector2.ZERO
    for coin in coins:
        sum += coin.direction
    assert_float(rad_to_deg(absf(sum.angle_to(aim)))).is_less(0.01)
    # The spread is the angle between the outermost coins.
    assert_float(rad_to_deg(absf(coins[0].direction.angle_to(coins[6].direction)))).is_equal_approx(60.0, 0.01)


func test_a_ring_leaves_its_gap_on_the_aim() -> void:
    var boss: Enemy = _make_boss()["boss"]
    var aim := Vector2.UP
    var count := 20
    var gap := 2

    var coins := _track(BossBullets.ring(boss, count, gap, aim))

    assert_int(coins.size()).is_equal(count - gap)
    var closest := PI
    for coin in coins:
        closest = minf(closest, absf(coin.direction.angle_to(aim)))
    # The aim sits in the middle of the gap: the nearest coin is a full
    # half-gap away on either side.
    assert_float(closest).is_equal_approx(TAU / count * (gap + 1) * 0.5, 0.0001)


func test_a_coin_damage_scales_with_the_boss_damage_stat() -> void:
    var boss: Enemy = _make_boss()["boss"]
    var first: Projectile = _track([BossBullets.fire(boss, Vector2.RIGHT)])[0]
    boss.stats.set_base_stat("damage", boss.stats.stats["damage"] * 2.0)

    var second: Projectile = _track([BossBullets.fire(boss, Vector2.RIGHT)])[0]

    assert_float(second.damage).is_equal_approx(first.damage * 2.0, 0.0001)


func test_a_coin_hurts_the_player_and_ignores_enemies() -> void:
    var boss: Enemy = _make_boss()["boss"]
    var coin: Projectile = _track([BossBullets.fire(boss, Vector2.RIGHT)])[0]
    var player := DamageableBody.spawn(_root, Vector2(500, 0))
    var player_before := player.current_health
    var boss_before := boss.health_node.current_health

    coin._on_area_entered(boss)
    assert_float(boss.health_node.current_health).is_equal(boss_before)
    coin._on_area_entered(player.get_parent())
    assert_float(player.current_health).is_less(player_before)


# --- attacks ------------------------------------------------------------------

func test_every_attack_finishes_and_leaves_the_boss_as_it_found_it() -> void:
    var ctx := _make_boss()
    var boss: Enemy = ctx["boss"]
    var brain: BossBrain = ctx["brain"]
    var speed_before := boss.stats.get_movement_speed_px()
    for attack in brain.attacks():
        var coins_before := _world().get_child_count()
        var ticks := _run_attack(attack, boss, ctx["target"])
        assert_int(ticks).override_failure_message("%s never finished" % attack.name).is_less(10000)
        assert_bool(attack.is_running()).is_false()
        assert_float(boss.stats.get_movement_speed_px()).override_failure_message(
            "%s left a speed modifier on the boss" % attack.name).is_equal_approx(speed_before, 0.0001)
        assert_object(boss.visual.modulate).is_equal(Color.WHITE)
        _collect_coins(coins_before)


func test_the_coin_attacks_fire_coins() -> void:
    var ctx := _make_boss()
    var boss: Enemy = ctx["boss"]
    for attack_name in ["CoinSpray", "DividendRing"]:
        var scene := _world()
        var before_count := scene.get_child_count()
        _run_attack(ctx["brain"].get_node(attack_name), boss, ctx["target"])
        assert_int(scene.get_child_count()).override_failure_message(
            "%s fired nothing" % attack_name).is_greater(before_count)
        _collect_coins(before_count)


func test_the_ram_locks_its_direction_when_the_telegraph_ends() -> void:
    var ctx := _make_boss()
    var boss: Enemy = ctx["boss"]
    var target: Node2D = ctx["target"]
    var ram: BossAttack = ctx["brain"].get_node("Ram")
    var telegraph := float(ram.cfg().get("telegraph", 0.9))

    ram.start(boss, target)
    while ram.step == BossAttack.Step.TELEGRAPH:
        ram.tick(STEP)
    var locked: Vector2 = ram.direction
    # The player moves after the lock: the charge must not follow.
    target.global_position = Vector2(0, 300)
    ram.tick(STEP)

    assert_float(boss.velocity.normalized().angle_to(locked)).is_equal_approx(0.0, 0.0001)
    assert_float(boss.velocity.length()).is_greater(0.0)
    assert_float(telegraph).is_greater(0.0)
    ram.stop()


func test_dying_mid_ram_takes_the_speed_boost_off() -> void:
    var ctx := _make_boss()
    var boss: Enemy = ctx["boss"]
    var brain: BossBrain = ctx["brain"]
    _reach_phase(ctx, 3)
    var speed_before := boss.stats.get_movement_speed_px()
    var ram: BossAttack = brain.get_node("Ram")
    brain.current_attack = ram
    ram.start(boss, ctx["target"])
    while ram.step == BossAttack.Step.TELEGRAPH:
        ram.tick(STEP)
    ram.tick(STEP)
    assert_float(boss.stats.get_movement_speed_px()).is_greater(speed_before)

    _hit(boss, boss.health_node.max_health * 10.0)

    assert_bool(boss.health_node.is_dead).is_true()
    assert_float(boss.stats.get_movement_speed_px()).is_equal_approx(speed_before, 0.0001)


## Frees whatever the attacks added to the scene after `count` children.
func _collect_coins(count: int) -> void:
    var scene := _world()
    if scene == null:
        return
    while scene.get_child_count() > count:
        scene.get_child(scene.get_child_count() - 1).free()


## Where `BossBullets` puts coins: the current scene, or the root without one.
func _world() -> Node:
    var scene := get_tree().current_scene
    return scene if scene != null else get_tree().root


# --- M2: phase-2 attacks, shockwave, adds -------------------------------------

## Puts a damageable stand-in for the player at the target's spot and makes it
## the boss's target, so attacks that aim at the target land on it.
func _player_as_target(ctx: Dictionary, at: Vector2) -> Health:
    var player := DamageableBody.spawn(_root, at)
    ctx["target"] = player.get_parent()
    (ctx["boss"] as Enemy).set_target_position(ctx["target"])
    return player


func _attack(ctx: Dictionary, attack_name: String) -> BossAttack:
    return (ctx["brain"] as BossBrain).get_node(attack_name) as BossAttack


func test_the_spiral_fires_whole_sets_of_arms() -> void:
    var ctx := _make_boss()
    var spiral := _attack(ctx, "CoinSpiral")
    var world := _world()
    var before_count := world.get_child_count()

    _run_attack(spiral, ctx["boss"], ctx["target"])

    var arms := int(spiral.cfg().get("arms", 2))
    var fired := world.get_child_count() - before_count
    assert_int(fired).is_greater(arms)
    assert_int(fired % arms).is_equal(0)
    _collect_coins(before_count)


func test_the_double_ram_charges_twice_and_re_aims_between() -> void:
    var ctx := _make_boss()
    var boss: Enemy = ctx["boss"]
    var target: Node2D = ctx["target"]
    var ram := _attack(ctx, "DoubleRam")
    ram.start(boss, target)
    while ram.step == BossAttack.Step.TELEGRAPH:
        ram.tick(STEP)
    var first: Vector2 = ram.direction
    while ram.charges_done == 0:
        ram.tick(STEP)
    # The player moves during the pause: the second charge follows them.
    target.global_position = boss.global_position + Vector2(0, 300)
    var guard := 0
    while ram.is_running() and guard < 10000:
        ram.tick(STEP)
        guard += 1

    assert_int(ram.charges_done).is_equal(int(ram.cfg().get("charges", 2)))
    assert_float(absf(first.angle_to(ram.direction))).is_greater(0.1)
    assert_float(ram.direction.angle_to(Vector2.DOWN)).is_equal_approx(0.0, 0.0001)


func test_the_safe_drop_lands_on_the_player_and_explodes() -> void:
    var ctx := _make_boss()
    var player := _player_as_target(ctx, Vector2(300, 0))
    var safe_drop := _attack(ctx, "SafeDrop")
    var health_before := player.current_health
    safe_drop.start(ctx["boss"], ctx["target"])
    while safe_drop.step == BossAttack.Step.TELEGRAPH:
        safe_drop.tick(STEP)
    safe_drop.tick(STEP)

    var markers: Array = safe_drop.markers.duplicate()
    assert_int(markers.size()).is_equal(int(safe_drop.cfg().get("count", 5)))
    assert_vector(markers[0].global_position).is_equal(player.get_parent().global_position)
    # No damage while the safes are still falling.
    assert_float(player.current_health).is_equal(health_before)

    while safe_drop.step == BossAttack.Step.ACTIVE:
        safe_drop.tick(STEP)

    assert_float(player.current_health).is_less(health_before)
    for marker in markers:
        assert_bool(marker.is_queued_for_deletion()).is_true()
    safe_drop.stop()


func test_the_burrowed_boss_cannot_be_hit_and_erupts_under_the_player() -> void:
    var ctx := _make_boss()
    var boss: Enemy = ctx["boss"]
    var player := _player_as_target(ctx, Vector2(300, 0))
    var burrow := _attack(ctx, "Burrow")
    var layer_before := boss.collision_layer
    var world_count := _world().get_child_count()
    var health_before := player.current_health
    # The brain asks its running attack whether to block a hit.
    (ctx["brain"] as BossBrain).current_attack = burrow
    burrow.start(boss, ctx["target"])
    while burrow.step == BossAttack.Step.TELEGRAPH:
        burrow.tick(STEP)
    burrow.tick(STEP)

    assert_bool(burrow.blocks_damage()).is_true()
    assert_float(_hit(boss, 1.0)).is_equal(0.0)
    assert_bool(boss.is_in_group("damageable")).is_false()
    assert_bool(boss.visual.visible).is_false()
    assert_int(boss.collision_layer).is_equal(0)

    while burrow.step == BossAttack.Step.ACTIVE:
        burrow.tick(STEP)

    # The mound caught the player while tracking, so the eruption is on them.
    assert_float(boss.global_position.distance_to(player.get_parent().global_position)).is_less(
        float(burrow.cfg().get("erupt_radius", 130.0)))
    assert_float(player.current_health).is_less(health_before)
    assert_bool(boss.is_in_group("damageable")).is_true()
    assert_bool(boss.visual.visible).is_true()
    assert_int(boss.collision_layer).is_equal(layer_before)
    assert_float(_hit(boss, 1.0)).is_greater(0.0)
    burrow.stop()
    (ctx["brain"] as BossBrain).current_attack = null
    _collect_coins(world_count)


func test_a_phase_change_knocks_a_close_player_away() -> void:
    var ctx := _make_boss()
    var boss: Enemy = ctx["boss"]
    var target: Node2D = ctx["target"]
    var radius := float(_config().get("shockwave_radius", 400.0))
    target.global_position = boss.global_position + Vector2(radius * 0.5, 0)

    _hit(boss, boss.health_node.max_health)

    var knock := target.get_node_or_null("KnockbackController") as KnockbackController
    assert_object(knock).is_not_null()
    assert_float(knock.knockback_velocity.x).is_greater(0.0)


func test_a_far_player_is_not_knocked_back() -> void:
    var ctx := _make_boss()
    var boss: Enemy = ctx["boss"]
    var target: Node2D = ctx["target"]
    var radius := float(_config().get("shockwave_radius", 400.0))
    target.global_position = boss.global_position + Vector2(radius * 2.0, 0)

    _hit(boss, boss.health_node.max_health)

    assert_object(target.get_node_or_null("KnockbackController")).is_null()


func test_adds_arrive_with_their_phase_and_die_when_it_ends() -> void:
    var ctx := _make_boss()
    var brain: BossBrain = ctx["brain"]
    var add_phases: Array = _config().get("adds_phases", [2])
    assert_bool(add_phases.has(1)).is_false()
    assert_int(brain.adds.size()).is_equal(0)

    _reach_phase(ctx, 2)
    var adds := brain.adds.duplicate()
    assert_int(adds.size()).is_equal(int(_config().get("adds_pack_size", 5)))
    for add in adds:
        assert_object(add.get_parent()).is_same((ctx["boss"] as Enemy).get_parent())

    _reach_phase(ctx, 3)
    for add in adds:
        assert_bool(add.health_node.is_dead).is_true()


func test_adds_never_exceed_the_cap() -> void:
    var ctx := _make_boss()
    var brain: BossBrain = ctx["brain"]
    _reach_phase(ctx, 2)
    for i in 10:
        brain._spawn_adds(ctx["boss"])
    assert_int(brain.adds.size()).is_equal(int(_config().get("adds_max_alive", 10)))


func test_the_adds_die_with_the_boss() -> void:
    var ctx := _make_boss()
    var boss: Enemy = ctx["boss"]
    var brain: BossBrain = ctx["brain"]
    _reach_phase(ctx, 2)
    var adds := brain.adds.duplicate()
    assert_int(adds.size()).is_greater(0)
    brain.phase = 3  # skip the clamp so one hit kills
    _hit(boss, boss.health_node.max_health * 10.0)

    assert_bool(boss.health_node.is_dead).is_true()
    for add in adds:
        assert_bool(add.health_node.is_dead).is_true()


# --- M3: phase-3 attacks, enrage, shield pop, death ---------------------------

func test_the_gold_rush_charges_once_per_bounce() -> void:
    var ctx := _make_boss()
    var rush := _attack(ctx, "GoldRush")
    _run_attack(rush, ctx["boss"], ctx["target"])
    assert_int(rush.charges_done).is_equal(int(rush.cfg().get("charges", 4)))
    assert_int(rush.charges_done).is_greater(int(_attack(ctx, "DoubleRam").cfg().get("charges", 2)))


func test_the_beam_sweeps_its_arc() -> void:
    var ctx := _make_boss()
    var beam := _attack(ctx, "GoldenBeam")
    beam.start(ctx["boss"], ctx["target"])
    while beam.step == BossAttack.Step.TELEGRAPH:
        beam.tick(STEP)
    var start_dir: Vector2 = beam.direction
    while beam.step == BossAttack.Step.ACTIVE:
        beam.tick(STEP)

    assert_float(rad_to_deg(absf(start_dir.angle_to(beam.direction)))).is_equal_approx(
        float(beam.cfg().get("arc_deg", 120.0)), 0.5)
    beam.stop()


func test_the_beam_burns_what_it_sweeps_over_and_not_what_is_behind() -> void:
    var ctx := _make_boss()
    var boss: Enemy = ctx["boss"]
    var player := _player_as_target(ctx, Vector2(300, 0))
    var behind := DamageableBody.spawn(_root, Vector2(-300, 0))
    var player_before := player.current_health
    var behind_before := behind.current_health

    _run_attack(_attack(ctx, "GoldenBeam"), boss, ctx["target"])

    assert_float(player.current_health).is_less(player_before)
    assert_float(behind.current_health).is_equal(behind_before)


func test_the_beam_hits_a_body_at_most_once_per_interval() -> void:
    var ctx := _make_boss()
    var player := _player_as_target(ctx, Vector2(300, 0))
    var beam := _attack(ctx, "GoldenBeam")
    var player_before := player.current_health
    var one_hit := float(beam.cfg().get("damage", 2.0)) * (ctx["boss"] as Enemy).stats.get_stat("damage")

    _run_attack(beam, ctx["boss"], ctx["target"])

    var hits := roundi((player_before - player.current_health) / one_hit)
    var sweep := float(beam.cfg().get("sweep_time", 2.5))
    var interval := float(beam.cfg().get("hit_interval", 0.4))
    assert_int(hits).is_greater(0)
    assert_int(hits).is_less_equal(ceili(sweep / interval) + 1)


func test_margin_call_hurts_the_far_and_spares_the_close() -> void:
    var ctx := _make_boss()
    var boss: Enemy = ctx["boss"]
    var margin := _attack(ctx, "MarginCall")
    var min_radius := float(margin.cfg().get("min_radius", 300.0))
    var close := _player_as_target(ctx, Vector2(min_radius * 0.5, 0))
    var far := DamageableBody.spawn(_root, Vector2(min_radius * 2.0, 0))
    var close_before := close.current_health
    var far_before := far.current_health

    margin.start(boss, ctx["target"])
    var ring: GroundMarker = margin.ring
    while margin.is_running():
        margin.tick(STEP)

    assert_float(far.current_health).is_less(far_before)
    assert_float(close.current_health).is_equal(close_before)
    assert_bool(ring.is_queued_for_deletion()).is_true()


func test_the_fight_enrages_after_its_time() -> void:
    var ctx := _make_boss()
    var boss: Enemy = ctx["boss"]
    var brain: BossBrain = ctx["brain"]
    var spray := _attack(ctx, "CoinSpray")
    var world_count := _world().get_child_count()
    var calm_ticks := _run_attack(spray, boss, ctx["target"])
    assert_bool(brain.enraged).is_false()

    brain.fight_time = float(_config().get("enrage_time", 150.0))
    brain.process_movement(boss, STEP)
    if brain.current_attack != null:
        brain.current_attack.stop()
        brain.current_attack = null

    assert_bool(brain.enraged).is_true()
    assert_object(boss.visual.modulate).is_equal(brain.enrage_tint)
    var enraged_ticks := _run_attack(spray, boss, ctx["target"])
    assert_int(enraged_ticks).is_less(calm_ticks)
    # The telegraph pulse settles back on the enraged tint, not on white.
    assert_object(boss.visual.modulate).is_equal(brain.enrage_tint)
    _collect_coins(world_count)


func test_phase_three_pops_the_plate_off() -> void:
    var ctx := _make_boss()
    _reach_phase(ctx, 2)
    var bursts_before := _count_bursts()
    _reach_phase(ctx, 3)
    assert_int(_count_bursts()).is_greater(bursts_before)


func test_the_kill_slows_time_and_sprays_coins() -> void:
    var ctx := _make_boss()
    var boss: Enemy = ctx["boss"]
    var brain: BossBrain = ctx["brain"]
    brain.phase = 3  # skip the clamp so one hit kills
    var world := _world()
    var world_count := world.get_child_count()

    _hit(boss, boss.health_node.max_health * 10.0)

    assert_float(Engine.time_scale).is_equal_approx(float(_config().get("death_time_scale", 0.3)), 0.0001)
    var fountain: CPUParticles2D = null
    for i in range(world_count, world.get_child_count()):
        if world.get_child(i) is CPUParticles2D:
            fountain = world.get_child(i)
    assert_object(fountain).is_not_null()
    assert_bool(fountain.emitting).is_true()
    _collect_coins(world_count)


func _count_bursts() -> int:
    var count := 0
    for child in _world().get_children():
        if child is ExplosionBurst:
            count += 1
    return count


# --- M4: boss bar, name card, shake, sound ------------------------------------

func test_the_boss_brings_its_own_bar_with_phase_ticks() -> void:
    var ctx := _make_boss()
    await get_tree().process_frame
    var brain: BossBrain = ctx["brain"]

    assert_object(brain.hud).is_not_null()
    assert_object(brain.hud.get_parent()).is_same(ctx["boss"])
    assert_array(brain.hud.bar.thresholds).is_equal(_config().get("phase_thresholds", []))
    assert_str(brain.hud.bar.title).is_equal(brain.boss_name)
    assert_object(brain.hud.name_card).is_not_null()


func test_the_bar_follows_the_boss_health() -> void:
    var ctx := _make_boss()
    await get_tree().process_frame
    var boss: Enemy = ctx["boss"]
    var bar: BossHealthBar = (ctx["brain"] as BossBrain).hud.bar

    _hit(boss, boss.health_node.max_health * 0.1)

    assert_float(bar.fraction).is_equal_approx(
        boss.health_node.current_health / boss.health_node.max_health, 0.0001)
    assert_float(bar.fraction).is_less(1.0)


func test_the_bar_turns_red_on_enrage() -> void:
    var ctx := _make_boss()
    await get_tree().process_frame
    var brain: BossBrain = ctx["brain"]
    var calm := brain.hud.bar.fill_color
    brain.fight_time = float(_config().get("enrage_time", 150.0))
    brain.process_movement(ctx["boss"], STEP)
    if brain.current_attack != null:
        brain.current_attack.stop()
        brain.current_attack = null

    assert_object(brain.hud.bar.fill_color).is_not_equal(calm)


func test_a_phase_change_shakes_the_camera() -> void:
    var saved_shake := GameSettings.screen_shake
    GameSettings.screen_shake = 100.0
    var ctx := _make_boss()
    var camera: Camera2D = load("res://src/Scripts/camera_2d.gd").new()
    _root.add_child(camera)
    camera.make_current()
    var boss: Enemy = ctx["boss"]

    _hit(boss, boss.health_node.max_health)

    assert_float(camera.shake_strength).is_greater(0.0)
    GameSettings.screen_shake = saved_shake


func test_a_telegraph_queues_its_sound() -> void:
    var ctx := _make_boss()
    var safe_drop := _attack(ctx, "SafeDrop")
    assert_object(safe_drop.telegraph_sound).is_not_null()
    SoundManager.sounds_to_play2d.clear()

    safe_drop.start(ctx["boss"], ctx["target"])

    assert_int(SoundManager.sounds_to_play2d.size()).is_greater(0)
    assert_object(SoundManager.sounds_to_play2d[0][0]).is_same(safe_drop.telegraph_sound)
    safe_drop.stop()


# --- debug seam -----------------------------------------------------------------

func test_skip_to_phase_lands_on_the_threshold_with_the_phase_applied() -> void:
    var ctx := _make_boss()
    var boss: Enemy = ctx["boss"]
    var brain: BossBrain = ctx["brain"]

    brain.skip_to_phase(3)

    assert_int(brain.phase).is_equal(3)
    assert_bool(brain.is_transitioning()).is_false()
    assert_float(boss.health_node.current_health).is_equal_approx(
        boss.health_node.max_health * _threshold(1), 0.001)
    assert_object(boss.sprite.texture).is_same(brain.broken_texture)
    # Phase 2's adds came and went with it.
    for add in brain.adds:
        assert_bool(add.health_node.is_dead).is_true()
