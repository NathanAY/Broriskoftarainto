## Shared setup for the weapon integration suites: they all drive a real
## TestScene (spawn the player, spawn a target, equip one weapon, simulate
## frames). The conventions that every one of them needs live here so a change
## to the scene, the health budget or the frame budget is made once.
class_name WeaponTestSupport
extends RefCounted

const TEST_SCENE := "res://test/TestScene.tscn"
const ENEMY_SCENE := "res://src/Systems/Enemy.tscn"

## Enemies carry no character data, so they run on the default `Stats` health of
## 10: one strong hit kills one. A dead enemy plays its death animation and then
## frees its whole node, which leaves the test holding a dangling `Health` -
## reading it raises a script error, and in a headless GdUnit run that error
## blocks on the debugger prompt until the run times out. The suites only need a
## target that outlives the window and shows the damage drop, so they give it
## this much health and assert on the drop.
const ENEMY_HEALTH := 40.0

## Frames to simulate at time factor 5. Weapon cycles are driven by a `Timer`
## that counts down in unscaled time while `simulate_frames` advances frames, so
## one cycle spans ~100-125 frames and a projectile needs ~55 more to cross the
## scene. 240 frames covers a full cycle plus travel for every weapon here, and
## still leaves each target alive.
const FRAMES := 60 * 4


## Equip `weapon_path` as the character's only weapon and return the live
## instance. Clearing the rest matters: the default character's starting weapon
## also reaches the near target, and its damage/knockback both skew the numbers
## and shove the target out of range.
static func equip_only_weapon(character: Character, weapon_path: String) -> BaseWeapon:
	for weapon in character.weapon_holder.weapons.duplicate():
		character.weapon_holder.remove_weapon(weapon)
	# duplicate: BaseWeapon is a Resource carrying mutable runtime state (firing
	# timer, cached damage, bound effect nodes), so suites must not share the
	# .tres instance.
	character.weapon_holder.add_weapon(load(weapon_path).duplicate(true))
	return character.weapon_holder.weapons[0]


## Raise a target to `ENEMY_HEALTH`, through its Stats so `max_health` and the
## health bar agree with the value, and return its Health node.
static func give_enemy_health(enemy: Enemy) -> Health:
	var health: Health = enemy.get_node("Health")
	enemy.get_node("Stats").set_base_stat("health", ENEMY_HEALTH)
	health.max_health = ENEMY_HEALTH
	health.current_health = ENEMY_HEALTH
	return health


## A second enemy `offset` behind `near_enemy`, on the projectile line.
static func spawn_enemy_behind(test_scene: Node, near_enemy: Enemy, offset: Vector2) -> Enemy:
	var enemy: Enemy = load(ENEMY_SCENE).instantiate()
	enemy.global_position = near_enemy.global_position + offset
	test_scene.add_child(enemy)
	return enemy


## Current health of `health`, or -1.0 when the node has been freed. Pair it with
## `assert_float(...).is_greater(0.0)`: a dead target then fails as a normal
## assertion (and fails the damage check too) instead of raising on a freed
## object and stalling the runner.
static func health_left(health: Health) -> float:
	if not is_instance_valid(health):
		return -1.0
	return health.current_health
