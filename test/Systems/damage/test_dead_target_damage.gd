# GdUnit TestSuite for the dead-target guard on the damage pipeline.
#
# A dying entity stays in the tree for its whole death animation - `Enemy._die`
# only frees the node from the `death` animation's `animation_finished` - and
# for that ~0.7s window it used to be a fully live scene member: still in the
# `damageable` group, colliders still on, `Health.take_damage` still accepting
# hits. So a corpse kept losing health and kept re-emitting the events that
# drive the visual effect managers: HitFlashManager flashed it,
# ParticleEffectManager spat particles out of it and TextureBurstManager burst
# it a second time per hit, while `on_kill` paid out StatOnKillModifier rewards
# and spawner_modifier handed over money and drops again.
#
# The fix has two halves, and each half is covered below:
#   * `Health.apply_damage()` owns the whole defender phase of the pipeline and
#     latches `is_dead`, so nothing fires for a hit on a corpse no matter which
#     damage source sent it.
#   * `Enemy._die` drops the corpse out of the target groups and switches off
#     both colliders, so weapons stop aiming at it in the first place.
class_name DeadTargetDamageTest
extends GdUnitTestSuite

const ENEMY_SCENE := "res://src/Systems/Enemy.tscn"

## Enemies carry no character data, so they start on the default `Stats` health
## of 10 - small enough that one hit kills, but the ratios stay awkward. This is
## the budget every test tops the target up to.
const TARGET_HEALTH := 100.0

## One hit is lethal against TARGET_HEALTH, and lands the damage fraction on 1.0
## so the hit effects spawn their normal amount instead of a burst of hundreds.
const LETHAL_HIT := 100.0

## Every event the three effect managers hang off, plus the ones that drive kill
## rewards. A hit on a corpse must produce none of them. Note the two buses: the
## `*_take_damage` / `on_death` / `on_health_changed` events are emitted on the
## defender's EventManager, `on_hit` / `on_kill` on the attacker's.
const WATCHED := [
    "before_take_damage",
    "after_take_damage",
    "on_death",
    "on_health_changed",
    "on_hit",
    "on_kill",
]

var _counts: Dictionary = {}
var _root: Node2D = null
var _enemy: Enemy = null
var _health: Health = null


func before_test() -> void:
    # The counters live on the suite, so a leak from one test would show up as
    # phantom events in the next one.
    _counts.clear()


func after_test() -> void:
    if is_instance_valid(_root):
        _root.free()


# -------------------
# Setup helpers
# -------------------

## A real `Enemy.tscn` in a bare container, so the burst spawned on death lands
## as a sibling of the enemy and can be counted.
func _spawn_enemy() -> void:
    _root = Node2D.new()
    _root.name = "World"
    add_child(_root)
    _enemy = load(ENEMY_SCENE).instantiate()
    _root.add_child(_enemy)
    _health = _enemy.get_node("Health")
    # Raise the budget through Stats so max_health, the health bar and the
    # damage fractions all agree with current_health.
    _enemy.get_node("Stats").set_base_stat("health", TARGET_HEALTH)
    _health.max_health = TARGET_HEALTH
    _health.current_health = TARGET_HEALTH
    _watch(_enemy.get_node("EventManager"))


## Start counting an event bus. `bind` appends the event name after the payload
## the bus delivers, and drops the callable to the one argument
## `EventContracts.check_subscribe` demands, so one recorder serves every event.
func _watch(bus: EventManager) -> void:
    for event_name in WATCHED:
        bus.subscribe(event_name, Callable(self, "_record").bind(event_name))


func _record(_payload: Dictionary, event_name: String) -> void:
    _counts[event_name] = int(_counts.get(event_name, 0)) + 1


func _count(event_name: String) -> int:
    return int(_counts.get(event_name, 0))


func _reset_counts() -> void:
    _counts.clear()


## Death bursts are added next to the enemy rather than inside it, precisely so
## they outlive it - which makes them a direct read on how many times
## TextureBurstManager ran.
func _burst_count() -> int:
    var total := 0
    for child in _root.get_children():
        if child is TextureBurst:
            total += 1
    return total


func _hit(amount: float) -> DamageContext:
    var ctx := DamageContext.new()
    ctx.target = _enemy
    ctx.base_amount = amount
    ctx.final_amount = amount
    ctx.tags.append("melee")
    return ctx


## The body shape stops new `body_entered` overlaps; the hitbox is an Area2D, so
## it outlives the body shape going away and the melee sweep's area raycast would
## keep resolving the corpse through it. Both have to go.
func _body_shape_disabled() -> bool:
    return (_enemy.get_node("CollisionShape2D") as CollisionShape2D).disabled


func _hitbox_shape_disabled() -> bool:
    return (_enemy.get_node("Hitbox/CollisionShape2D") as CollisionShape2D).disabled


func _assert_silent_damage() -> void:
    for event_name in WATCHED:
        assert_int(_count(event_name)).override_failure_message(
            "'%s' fired for a hit on a corpse" % event_name).is_equal(0)


# -------------------
# The guard itself
# -------------------

func test_lethal_hit_lands_and_latches_is_dead() -> void:
    _spawn_enemy()

    assert_bool(_health.apply_damage(_hit(LETHAL_HIT))).is_true()

    assert_float(_health.current_health).is_equal(0.0)
    assert_bool(_health.is_dead).is_true()
    # A single lethal hit is still a full hit: flash, particles, one death burst.
    assert_int(_count("before_take_damage")).is_equal(1)
    assert_int(_count("after_take_damage")).is_equal(1)
    assert_int(_count("on_health_changed")).is_equal(1)
    assert_int(_count("on_death")).is_equal(1)
    assert_int(_burst_count()).is_equal(1)


func test_hit_during_death_animation_is_fully_ignored() -> void:
    _spawn_enemy()
    assert_bool(_health.apply_damage(_hit(LETHAL_HIT))).is_true()

    # Sit inside the death animation: the corpse is still in the tree, still
    # playing "death", and that window is exactly where the bug lived.
    await get_tree().process_frame
    assert_bool(is_instance_valid(_enemy)).is_true()
    assert_str(_enemy.anim_player.current_animation).is_equal("death")

    var health_at_death: float = _health.current_health
    var bursts_at_death: int = _burst_count()
    _reset_counts()

    assert_bool(_health.apply_damage(_hit(25.0))).is_false()

    assert_float(_health.current_health).is_equal(health_at_death)
    _assert_silent_damage()
    assert_int(_burst_count()).is_equal(bursts_at_death)


func test_repeated_hits_never_re_emit_death() -> void:
    _spawn_enemy()
    assert_bool(_health.apply_damage(_hit(LETHAL_HIT))).is_true()
    _reset_counts()

    for _i in 5:
        _health.apply_damage(_hit(25.0))

    _assert_silent_damage()


func test_replayed_death_event_does_not_re_run_death_handling() -> void:
    _spawn_enemy()
    var bus: EventManager = _enemy.get_node("EventManager")
    var ctx := _hit(LETHAL_HIT)
    assert_bool(_health.apply_damage(ctx)).is_true()
    await get_tree().process_frame

    var anim: AnimationPlayer = _enemy.anim_player
    var position_before: float = anim.current_animation_position
    _reset_counts()

    # Health only ever emits on_death once, but a duplicate from anywhere else
    # must not re-run Enemy._die: restarting "death" would reset the 0.7s window
    # and queue a second free on animation_finished.
    bus.emit_event("on_death", {"self": _enemy, "damage_context": ctx})

    assert_float(anim.current_animation_position).override_failure_message(
        "the death animation was restarted by a duplicate on_death").is_equal(position_before)
    assert_bool(_enemy.is_in_group("damageable")).is_false()
    # The corpse is still latched dead, so the follow-up hit is still dropped.
    assert_bool(_health.apply_damage(_hit(25.0))).is_false()


func test_live_target_still_takes_damage() -> void:
    _spawn_enemy()

    assert_bool(_health.apply_damage(_hit(30.0))).is_true()

    assert_float(_health.current_health).is_equal(TARGET_HEALTH - 30.0)
    assert_bool(_health.is_dead).is_false()
    assert_int(_count("before_take_damage")).is_equal(1)
    assert_int(_count("after_take_damage")).is_equal(1)
    assert_int(_count("on_health_changed")).is_equal(1)
    assert_int(_count("on_death")).is_equal(0)
    assert_int(_burst_count()).is_equal(0)


# -------------------
# Stopping the corpse being a target
# -------------------

func test_dead_enemy_leaves_target_groups_and_colliders() -> void:
    _spawn_enemy()
    assert_bool(_enemy.is_in_group("damageable")).is_true()
    assert_bool(_enemy.is_in_group("enemies")).is_true()
    assert_bool(_body_shape_disabled()).is_false()
    assert_bool(_hitbox_shape_disabled()).is_false()

    _health.apply_damage(_hit(LETHAL_HIT))
    # Switching the colliders off is deferred, so give it the frame it asks for.
    await get_tree().process_frame

    # Every TargetSelector walks "damageable", and lowest_hp actively preferred a
    # corpse with health <= 0, so leaving it in the group wasted the player's
    # shots on it.
    assert_bool(_enemy.is_in_group("damageable")).is_false()
    assert_bool(_enemy.is_in_group("enemies")).is_false()
    assert_bool(_body_shape_disabled()).is_true()
    assert_bool(_hitbox_shape_disabled()).is_true()


func test_projectile_stops_reporting_hits_once_the_target_is_a_corpse() -> void:
    _spawn_enemy()
    var attacker_bus := EventManager.new()
    attacker_bus.name = "AttackerEventManager"
    _root.add_child(attacker_bus)
    _watch(attacker_bus)

    var projectile := Projectile.new()
    projectile.damage = LETHAL_HIT
    _root.add_child(projectile)
    projectile.attachEventManager(attacker_bus)

    # The killing blow still reports itself, once.
    projectile.do_damage(_enemy)
    assert_int(_count("on_hit")).is_equal(1)
    assert_int(_count("on_kill")).is_equal(1)
    _reset_counts()

    # Every projectile after it is a miss: no on_hit, so no chain/bounce, and no
    # on_kill, so StatOnKillModifier and the kill rewards are not paid again.
    for _i in 4:
        projectile.do_damage(_enemy)

    _assert_silent_damage()
