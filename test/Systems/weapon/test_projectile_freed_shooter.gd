## Regression: an enemy projectile outlives the enemy that fired it. The projectile
## keeps the shooter's EventManager, which is freed with the shooter, so a hit
## after the shooter's death must still land without passing the freed bus into
## `Damage.deal` (that raised "previously freed" and stopped the run).
class_name ProjectileFreedShooterTest
extends GdUnitTestSuite


func test_projectile_hit_after_shooter_freed_still_damages() -> void:
    var runner := scene_runner("res://test/TestScene.tscn")
    var test_scene := runner.scene()
    get_tree().current_scene = test_scene

    var character: Character = test_scene.get_node("Character")
    var health: Health = character.get_node("Health")
    var health_before := health.current_health

    var projectile := Projectile.new()
    projectile.damage = 1.0
    var shooter_bus := EventManager.new()
    projectile.attachEventManager(shooter_bus)
    # The shooter dies while the projectile is still in flight.
    shooter_bus.free()

    projectile.do_damage(character)

    assert_float(WeaponTestSupport.health_left(health)).override_failure_message(
        "Projectile hit after its shooter died dealt no damage to the target"
    ).is_less(health_before)
    projectile.free()
    test_scene.free()
