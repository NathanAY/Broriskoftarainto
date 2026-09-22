# GdUnit generated TestSuite
class_name BounceModifierTest
extends GdUnitTestSuite

func test_bouncing_modifier() -> void:
    var runner := scene_runner("res://test/TestScene.tscn")
    var test_scene := runner.scene()
    runner.set_time_factor(5)
    get_tree().current_scene = test_scene

    var enemy: Enemy = test_scene.get_node("Enemy")
    var enemy2 = preload("res://src/Systems/Enemy.tscn").instantiate()
    # Off the +X firing line (Character at 100,100 shoots east toward Enemy at
    # 300,100): a straight projectile can never reach enemy2, only a bounced one.
    enemy2.global_position = enemy.global_position + Vector2(100, 300)
    test_scene.add_child(enemy2)
    
    var e1_health: Health = enemy.get_node("Health")
    var e2_health: Health = enemy2.get_node("Health")

    var character: Character = test_scene.get_node("Character")
    
    var item: Item = _create_item("ProjectileBounceModifier.tscn", 1)
    for weapon in character.weapon_holder.weapons.duplicate():
        character.weapon_holder.remove_weapon(weapon)
    character.item_holder.add_item(item)
    # Stock Pistol.tres ships a built-in pierce; a piercing projectile passes
    # through the first enemy and never triggers its bounce behavior (projectile.gd
    # only runs behaviors once pierce is exhausted), so use a plain pierce-free
    # copy for a pure bounce test.
    character.weapon_holder.add_weapon(_plain_pistol())
        
    await runner.simulate_frames(60 * 2.5)

    # enemy1 must be hit by the single pistol projectile (Fist was removed, so the
    # exact HP is one 35 damage hit; assert the hit landed at all instead of the
    # timing-fragile exact value).
    assert_float(e1_health.current_health).is_less(40.0)
    # enemy2 is off the straight firing line, so damage there can only come from
    # the bounced projectile. Any amount below 40 proves the bounce reached it.
    assert_float(e2_health.current_health).is_less(40.0)
    test_scene.free()


func _create_item(modifier_name: String, amount: float) -> Item:
    var modifier_scene: PackedScene = load("res://src/Systems/Items/Modifiers/" + modifier_name)
    return ItemBuilder.make_effect_item(
        "Buff_%s_%s" % [modifier_name, str(amount)],
        "Buff: +%s %s" % [amount, modifier_name],
        modifier_scene
    )


# A copy of the Pistol without its built-in pierce/knockback, so the test focuses
# on the bounce item only (see test_pierce_stat.gd for the same strip pattern).
func _plain_pistol() -> BaseWeapon:
    var pistol: BaseWeapon = load("res://src/Resources/weapons/Pistol.tres").duplicate(true)
    (pistol.modifiers as Dictionary).erase("pierce")
    (pistol.modifiers as Dictionary).erase("knockback")
    return pistol
