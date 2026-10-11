# The loop-1 boss used to swing two melee Fists. Its wander behaviour keeps it
# only 50-200 px from the player, so those swings were effectively unavoidable
# and killed most characters in a couple of hits. This suite pins the
# replacement: the boss carries shotguns whose pellets travel slower than an
# ordinary shot, so the blast can be walked out of.
class_name BossLoadoutTest
extends GdUnitTestSuite

const BOSS_SPAWNER := "res://src/Systems/BossSpawner.tscn"
const PROJECTILE := "res://src/Systems/weapon/Projectile.tscn"
const BOSS_SHOTGUN := "res://src/Resources/weapons/boss/BossShotgun.tres"


## Minimal runtime tree matching the BossSpawner's `../../Nodes/Enemies` contract
## (the same harness `test_spawner_arena.gd` uses), then spawns the loop-1 boss.
func _spawn_boss() -> BossSpawner:
	var root: Node = auto_free(Node.new())
	add_child(root)
	var nodes := Node.new()
	nodes.name = "Nodes"
	root.add_child(nodes)
	var enemies := Node.new()
	enemies.name = "Enemies"
	nodes.add_child(enemies)
	var stage := Node.new()
	stage.name = "StageManager"
	root.add_child(stage)
	var character: Character = auto_free(load("res://src/Systems/Character.tscn").instantiate())
	root.add_child(character)
	var spawner: BossSpawner = auto_free(load(BOSS_SPAWNER).instantiate())
	spawner.character = character
	stage.add_child(spawner)
	spawner.spawn_boss()
	return spawner


func test_boss_carries_a_shotgun_and_no_melee_fist() -> void:
	var spawner := _spawn_boss()
	var melee_count := 0
	var shotgun_count := 0
	for weapon in spawner.boss_instance.weapon_holder.weapons:
		if weapon is MeleeWeapon:
			melee_count += 1
		if weapon is ShotgunWeapon:
			shotgun_count += 1
	assert_int(melee_count).override_failure_message(
		"the boss should no longer swing melee fists").is_equal(0)
	assert_int(shotgun_count).override_failure_message(
		"the boss should carry its shotgun").is_greater(0)


func test_boss_pellets_travel_slower_than_a_plain_projectile() -> void:
	var spawner := _spawn_boss()
	var shotgun: ShotgunWeapon = null
	for weapon in spawner.boss_instance.weapon_holder.weapons:
		if weapon is ShotgunWeapon:
			shotgun = weapon
			break
	assert_object(shotgun).is_not_null()

	# Derived, not pinned: the bar is whatever a plain projectile authors, so
	# rebalancing either number keeps the relationship assertion honest.
	var plain: Projectile = load(PROJECTILE).instantiate()
	var plain_speed: float = plain.base_speed
	plain.free()
	assert_float(Stats.meters_to_px(shotgun.projectile_speed)).override_failure_message(
		"boss pellets must fly slower than a plain projectile to be dodgeable"
	).is_less(plain_speed)


func test_boss_shotgun_is_not_in_the_shop_weapon_pool() -> void:
	# The shop factory, the starter menu and the config panel all scan
	# `src/Resources/weapons/*.tres` non-recursively, so a boss weapon left in
	# the weapons root would silently become a purchasable item. It lives in the
	# skipped `boss/` subdirectory instead; this pins that placement.
	var factory := ItemFactory.new()
	factory._load_weapons()
	var offered: Array[String] = []
	for weapon in factory.weapon_resources:
		offered.append(weapon.resource_path)
	factory.free()
	assert_bool(BOSS_SHOTGUN in offered).override_failure_message(
		"the boss shotgun leaked into the shop weapon pool").is_false()
