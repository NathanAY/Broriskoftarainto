# GdUnit tests for weapon built-in modifiers (BaseWeapon.modifiers).
# Covers: scoping (a knife's poison never fires on a fist's hits and vice versa),
# fist knockback, knife poison, pistol built-in pierce, and detach cleanup.
class_name WeaponBuiltinModifiersTest
extends GdUnitTestSuite

const FIST := "res://src/Resources/weapons/Fist.tres"
const KNIFE := "res://src/Resources/weapons/Knife.tres"
const PISTOL := "res://src/Resources/weapons/Pistol.tres"

const KNOCKBACK_SCRIPT := "res://src/Systems/Items/modifiers/knockback_modifier.gd"
const POISON_SCRIPT := "res://src/Systems/Items/modifiers/poison_modifier.gd"


func test_bound_poison_only_fires_on_its_weapon() -> void:
    var runner := scene_runner("res://test/TestScene.tscn")
    var test_scene := runner.scene()
    get_tree().current_scene = test_scene

    var character: Character = test_scene.get_node("Character")
    var enemy: Enemy = test_scene.get_node("Enemy")
    var health_node: Health = enemy.get_node("Health")

    for weapon in character.weapon_holder.weapons.duplicate():
        character.weapon_holder.remove_weapon(weapon)

    var em: EventManager = character.get_node("EventManager")
    var poison: BaseModifier = preload(POISON_SCRIPT).new()
    poison.bound_weapon = load(KNIFE)
    poison.poison_chance = 1.0
    character.add_child(poison)
    poison.attachEventManager(em)

    var other_weapon: BaseWeapon = load(FIST).duplicate(true)

    var ctx := DamageContext.new()
    ctx.source = character
    ctx.target = enemy
    ctx.base_amount = 10.0

    # a hit from another weapon must NOT poison
    em.emit_event("on_hit", {"weapon": other_weapon, "body": enemy, "damage_context": ctx})
    assert_that(health_node.get_node_or_null("PoisonEffect")).is_null()

    # a hit from the bound weapon applies poison
    em.emit_event("on_hit", {"weapon": poison.bound_weapon, "body": enemy, "damage_context": ctx})
    assert_that(health_node.get_node_or_null("PoisonEffect")).is_not_null()

    test_scene.free()


func test_bound_knockback_only_fires_on_its_weapon() -> void:
    var runner := scene_runner("res://test/TestScene.tscn")
    var test_scene := runner.scene()
    get_tree().current_scene = test_scene

    var character: Character = test_scene.get_node("Character")
    var enemy: Enemy = test_scene.get_node("Enemy")

    for weapon in character.weapon_holder.weapons.duplicate():
        character.weapon_holder.remove_weapon(weapon)

    var em: EventManager = character.get_node("EventManager")
    var knockback: BaseModifier = preload(KNOCKBACK_SCRIPT).new()
    knockback.bound_weapon = load(FIST)
    character.add_child(knockback)
    knockback.attachEventManager(em)

    var other_weapon: BaseWeapon = load(KNIFE).duplicate(true)

    var ctx := DamageContext.new()
    ctx.source = character
    ctx.target = enemy
    ctx.base_amount = 10.0

    # a hit from another weapon must NOT knock back
    em.emit_event("on_hit", {"weapon": other_weapon, "body": enemy, "damage_context": ctx})
    assert_that(enemy.get_node_or_null("KnockbackController")).is_null()

    # a hit from the bound weapon knocks back
    em.emit_event("on_hit", {"weapon": knockback.bound_weapon, "body": enemy, "damage_context": ctx})
    assert_that(enemy.get_node_or_null("KnockbackController")).is_not_null()

    test_scene.free()


func test_knife_builtin_poison_applied() -> void:
    var runner := scene_runner("res://test/TestScene.tscn")
    var test_scene := runner.scene()
    runner.set_time_factor(5)
    get_tree().current_scene = test_scene

    var enemy: Enemy = test_scene.get_node("Enemy")
    var e_health: Health = enemy.get_node("Health")
    var character: Character = test_scene.get_node("Character")

    for weapon in character.weapon_holder.weapons.duplicate():
        character.weapon_holder.remove_weapon(weapon)

    var knife: BaseWeapon = load(KNIFE).duplicate(true)
    var poison_cfg: Dictionary = (knife.modifiers as Dictionary)["poison"]
    poison_cfg["chance"] = 1.0
    poison_cfg["tick_interval"] = 0.25
    character.weapon_holder.add_weapon(knife)

    # plenty of headroom so fast poison ticks cannot kill the enemy mid-test
    e_health.max_health = 200.0
    e_health.current_health = 200.0

    await runner.simulate_frames(60 * 2)

    # the built-in poison modifier node is bound to the knife
    assert_that(character.weapon_holder.weapons[0]._bound_effect_nodes.size()).is_equal(1)
    # enemy got poisoned (PoisonEffect lives on its Health node)
    assert_that(e_health.get_node_or_null("PoisonEffect")).is_not_null()
    # 0.25s poison ticks plus the knife hit deal far more than the 5-damage hit
    assert_float(e_health.current_health).is_less(195.0)

    test_scene.free()


func test_fist_builtin_knockback_bound() -> void:
    var runner := scene_runner(WeaponTestSupport.TEST_SCENE)
    var test_scene := runner.scene()
    runner.set_time_factor(5)
    get_tree().current_scene = test_scene

    var enemy: Enemy = test_scene.get_node("Enemy")
    var e_health := WeaponTestSupport.give_enemy_health(enemy)
    var character: Character = test_scene.get_node("Character")

    var fist := WeaponTestSupport.equip_only_weapon(character, FIST)

    await runner.simulate_frames(WeaponTestSupport.FRAMES)

    # the built-in knockback modifier node is bound to the fist
    assert_that(fist._bound_effect_nodes.size()).is_equal(1)
    # fist damage still worked, and the target is still standing: binding the
    # knockback must not have swallowed the weapon's own hits
    var left := WeaponTestSupport.health_left(e_health)
    assert_float(left).override_failure_message(
        "the enemy died and freed its Health node").is_greater(0.0)
    assert_float(left).override_failure_message(
        "the fist dealt no damage").is_less(WeaponTestSupport.ENEMY_HEALTH)

    test_scene.free()


func test_pistol_builtin_pierce_hits_enemy_behind() -> void:
    var runner := scene_runner(WeaponTestSupport.TEST_SCENE)
    var test_scene := runner.scene()
    runner.set_time_factor(5)
    get_tree().current_scene = test_scene

    var enemy: Enemy = test_scene.get_node("Enemy")
    # second enemy sits on the projectile path, beyond any melee/targeting range
    var enemy2 := WeaponTestSupport.spawn_enemy_behind(test_scene, enemy, Vector2(350, 0))

    var e_health := WeaponTestSupport.give_enemy_health(enemy)
    var e2_health := WeaponTestSupport.give_enemy_health(enemy2)
    var character: Character = test_scene.get_node("Character")

    # built-in pierce (spawn-time) + knockback (hit-event), left fully intact
    var pistol := WeaponTestSupport.equip_only_weapon(character, PISTOL)

    await runner.simulate_frames(WeaponTestSupport.FRAMES)

    # only the bound knockback node exists for the pistol (pierce is spawn-time)
    assert_that(pistol._bound_effect_nodes.size()).is_equal(1)
    # a piercing pistol projectile reached the enemy behind the first one, which
    # starts at full health and so must have dropped below it
    var far_left := WeaponTestSupport.health_left(e2_health)
    assert_float(far_left).override_failure_message(
        "the far enemy died and freed its Health node").is_greater(0.0)
    assert_float(far_left).override_failure_message(
        "no projectile pierced through to the enemy behind").is_less(
            WeaponTestSupport.ENEMY_HEALTH)

    test_scene.free()


func test_remove_weapon_detaches_builtins() -> void:
    var runner := scene_runner("res://test/TestScene.tscn")
    var test_scene := runner.scene()
    get_tree().current_scene = test_scene

    var enemy: Enemy = test_scene.get_node("Enemy")
    var character: Character = test_scene.get_node("Character")

    for weapon in character.weapon_holder.weapons.duplicate():
        character.weapon_holder.remove_weapon(weapon)

    character.weapon_holder.add_weapon(load(FIST))
    var fist_inst: BaseWeapon = character.weapon_holder.weapons[0]
    assert_that(fist_inst._bound_effect_nodes.size()).is_equal(1)

    character.weapon_holder.remove_weapon(fist_inst)
    await runner.simulate_frames(2)

    # after removal, the weapon's hits must no longer trigger anything
    var em: EventManager = character.get_node("EventManager")
    var ctx := DamageContext.new()
    ctx.source = character
    ctx.target = enemy
    ctx.base_amount = 10.0
    em.emit_event("on_hit", {"weapon": fist_inst, "body": enemy, "damage_context": ctx})
    assert_that(enemy.get_node_or_null("KnockbackController")).is_null()

    test_scene.free()
