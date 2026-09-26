# GdUnit TestSuite for the `projectile_pierce` stat path.
#
# A/B on the stat alone: both cases equip a Pistol with its built-in `pierce`
# and `knockback` stripped, because `projectile_weapon.shoot_projectile` builds
# the projectile's pierce as `stats.get_stat("projectile_pierce") + the weapon's
# built-in pierce`. Stripping the built-in leaves the stat as the only source,
# so the two cases differ by exactly one stat item.
class_name PierceStatTest
extends GdUnitTestSuite

const PISTOL := "res://src/Resources/weapons/Pistol.tres"
const ENEMY_SCENE := "res://src/Systems/Enemy.tscn"

## Enemies have no character data, so they run on the default `Stats` health of
## 10 - two pistol shots kill one. A dead enemy plays its death animation and
## then frees its whole node, which leaves the test holding a dangling `Health`
## reference: reading it raises a script error, and a script error blocks the
## headless GdUnit runner on the debugger prompt until the run times out. The
## targets only have to outlive the observation window, never die.
const TARGET_HEALTH := 1000.0

## Frames simulated at time factor 5. Weapon cycles are driven by a `Timer`, and
## the timer counts down in unscaled time while `simulate_frames` advances the
## frames, so one pistol cycle (1.25s wait) spans ~125 frames here; a projectile
## then needs ~55 more frames to travel the 550px to the far target. 240 frames
## covers a full shot-and-land cycle with margin, so the outcome does not depend
## on where the window happens to end.
const FRAMES := 60 * 4


func test_piercing_stat_hits_enemy_behind() -> void:
	var runner := scene_runner("res://test/TestScene.tscn")
	var test_scene := runner.scene()
	runner.set_time_factor(5)
	get_tree().current_scene = test_scene

	var character := _prepare(test_scene)
	var near_enemy: Enemy = test_scene.get_node("Enemy")
	var far_enemy := _spawn_far_enemy(test_scene, near_enemy)
	var near_health := _make_survivable(near_enemy)
	var far_health := _make_survivable(far_enemy)

	character.item_holder.add_item(_create_pierce_item(1.0))
	character.weapon_holder.add_weapon(_pistol_without_builtins())

	await runner.simulate_frames(FRAMES)

	if not _assert_targets_alive(near_health, far_health):
		test_scene.free()
		return
	# The near enemy is hit by the pistol.
	assert_float(near_health.current_health).is_less(TARGET_HEALTH)
	# The far enemy is only reachable by a projectile that pierced through the
	# near one - nothing else targets or reaches it.
	assert_float(far_health.current_health).is_less(TARGET_HEALTH)
	test_scene.free()


func test_no_pierce_does_not_hit_enemy_behind() -> void:
	var runner := scene_runner("res://test/TestScene.tscn")
	var test_scene := runner.scene()
	runner.set_time_factor(5)
	get_tree().current_scene = test_scene

	var character := _prepare(test_scene)
	var near_enemy: Enemy = test_scene.get_node("Enemy")
	var far_enemy := _spawn_far_enemy(test_scene, near_enemy)
	var near_health := _make_survivable(near_enemy)
	var far_health := _make_survivable(far_enemy)

	character.weapon_holder.add_weapon(_pistol_without_builtins())

	await runner.simulate_frames(FRAMES)

	if not _assert_targets_alive(near_health, far_health):
		test_scene.free()
		return
	# The near enemy is hit, so the pistol did fire and did connect.
	assert_float(near_health.current_health).is_less(TARGET_HEALTH)
	# Without pierce the projectile is consumed by the near enemy, so the far one
	# is never touched at all.
	assert_float(far_health.current_health).is_equal(TARGET_HEALTH)
	test_scene.free()


# -------------------
# Setup helpers
# -------------------

## Strip every weapon so only the weapon under test acts: the default character's
## starting weapon also reaches the near enemy and would add its own damage and
## knockback, shoving the targets off the projectile line.
func _prepare(test_scene: Node) -> Character:
	var character: Character = test_scene.get_node("Character")
	for weapon in character.weapon_holder.weapons.duplicate():
		character.weapon_holder.remove_weapon(weapon)
	return character


## The second target, directly behind the first one on the projectile line: the
## character sits at (100,100) and shoots east, so a projectile that pierces the
## near enemy continues +X into this one. 350px behind puts it at 550px from the
## character - outside the pistol's 400px range - so only a piercing projectile
## can ever reach it.
func _spawn_far_enemy(test_scene: Node, near_enemy: Enemy) -> Enemy:
	var far_enemy: Enemy = load(ENEMY_SCENE).instantiate()
	far_enemy.global_position = near_enemy.global_position + Vector2(350, 0)
	test_scene.add_child(far_enemy)
	return far_enemy


## Top the target's health up so it survives the window instead of dying and
## freeing the node. The stat is set as well so `max_health` (which the stat
## change event refreshes) and the health bar agree with `current_health`.
func _make_survivable(enemy: Enemy) -> Health:
	var health: Health = enemy.get_node("Health")
	enemy.get_node("Stats").set_base_stat("health", TARGET_HEALTH)
	health.max_health = TARGET_HEALTH
	health.current_health = TARGET_HEALTH
	return health


func _pistol_without_builtins() -> BaseWeapon:
	var pistol: BaseWeapon = load(PISTOL).duplicate(true)
	(pistol.modifiers as Dictionary).erase("pierce")
	(pistol.modifiers as Dictionary).erase("knockback")
	return pistol


## A freed `Health` cannot be read, so report a dead target as a plain failure
## (with the reason) and let the caller bail out instead of raising a script
## error that stalls the runner.
func _assert_targets_alive(near_health: Health, far_health: Health) -> bool:
	var alive := is_instance_valid(near_health) and is_instance_valid(far_health)
	assert_bool(alive).override_failure_message(
		"a target died and freed its Health node - TARGET_HEALTH is too low").is_true()
	return alive


func _create_pierce_item(amount: float) -> Item:
	return ItemBuilder.make_stat_item(
		"Pierce_%s" % str(amount),
		"Pierce: +%s projectile_pierce" % str(amount),
		{"projectile_pierce": {"flat": amount}}
	 )
