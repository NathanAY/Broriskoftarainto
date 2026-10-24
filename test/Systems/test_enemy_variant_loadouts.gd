# The roster rows are enemy scenes that differ from the basic enemy only in
# their data - their stats, their sprite, their loadout. Nothing about them is
# code, so the only thing a test can catch is the *shape* of a row: that it
# carries the children the enemy contract needs, that it arms the weapons its
# role says it arms, and that its numbers move it away from the basic enemy in
# the direction its role says they should.
#
# The numbers themselves are `.tscn` data and are deliberately not pinned here.
# A balance pass must not turn this suite red, so the assertions compare one
# enemy against another instead of against a literal.
class_name EnemyVariantLoadoutsTest
extends GdUnitTestSuite

const GRUNT_SCENE := "res://src/Systems/Enemy.tscn"
const BULWARK_SCENE := "res://src/Systems/EnemyBulwark.tscn"
const GUNNER_SCENE := "res://src/Systems/EnemyGunner.tscn"
const SLIMELING_SCENE := "res://src/Systems/EnemySlimeling.tscn"

## The roster, by row. What each row arms and how it differs from the basic
## enemy is its role, so it belongs here rather than in the assertions.
const VARIANTS := [
	{
		"name": "Bulwark",
		"scene": "res://src/Systems/EnemyBulwark.tscn",
		# It is the contact-damage wall, so it keeps Thorns.
		"weapon": "contact",
		# It trades its speed for its health. That is the whole row.
		"tougher_than_grunt": true,
		"slower_than_grunt": true,
	},
	{
		"name": "Gunner",
		"scene": "res://src/Systems/EnemyGunner.tscn",
		# It shoots, so it arms a projectile weapon and no contact weapon.
		"weapon": "ranged",
		# It is not a wall and not a sprinter: it trades speed for range.
		"slower_than_grunt": true,
	},
	{
		"name": "Slimeling",
		"scene": "res://src/Systems/EnemySlimeling.tscn",
		# It dies into copies of itself, so it keeps the contact weapon: each
		# mini is a body you still have to deal with.
		"weapon": "contact",
		# It is a soft target: the split is what it costs you, not its health.
		"fragile_than_grunt": true,
	},
]

## The children every enemy scene has to carry. `Enemy` reaches for all of
## them by name, so a variant missing one is a crash in the arena rather than
## a weaker enemy.
const REQUIRED_CHILDREN := [
	"Stats",
	"Health",
	"WeaponHolder",
	"ItemHolder",
	"EventManager",
	"MovementBehaviour",
	"CollisionShape2D",
	"Hitbox",
	"Node2D/Sprite2D",
]

## Physics frames the contact weapon needs to land a hit. Thorns fires at 1.6
## attacks a second, so this covers its first swing with room to spare.
const PHYSICS_FRAMES := 75

## Physics frames a variant needs to close a visible gap. The Bulwark walks at a
## fraction of the basic enemy's speed, so it needs a few.
const CHASE_FRAMES := 20

## Where the chase target stands, in pixels, so the enemy has to walk.
const CHASE_DISTANCE := 400.0

## Physics frames the Gunner needs to walk from `GUNNER_START_DISTANCE` into its
## firing distance. The gap is closed at a fraction of the basic enemy's speed,
## so this is generous rather than tuned.
const GUNNER_FRAMES := 80

## Where the Gunner's target starts, in pixels: far outside its firing distance,
## so it has to walk before it can hold the line.
const GUNNER_START_DISTANCE := 320.0

## Physics frames a shot needs to leave the Gunner and reach a target standing
## in its reach. The pistol fires at 0.8 attacks a second and its projectile
## crosses the gap in well under a second.
const SHOOT_FRAMES := 130

## Where the body the Gunner shoots stands, in pixels. Inside the pistol's
## reach, so the shot is legal, but outside the firing distance, so the Gunner
## is walking towards it rather than standing on top of it.
const GUNNER_TARGET_DISTANCE := 300.0

var _world: Node2D = null


func after_test() -> void:
	if is_instance_valid(_world):
		if get_tree().current_scene == _world:
			get_tree().current_scene = null
		_world.free()


## The container the test's actors live in.
##
## It is parented to the tree root and made the current scene, because a weapon
## spawns its projectiles into `get_tree().current_scene`, and a GdUnit suite has
## none of its own. `current_scene` only accepts a child of the root, so this
## node cannot live under the suite.
func _world_root() -> Node2D:
	if not is_instance_valid(_world):
		_world = Node2D.new()
		_world.name = "World"
		get_tree().root.add_child(_world)
		get_tree().current_scene = _world
	return _world


## An enemy of `scene_path` in the test world.
func _spawn_enemy(scene_path: String) -> Enemy:
	var enemy: Enemy = load(scene_path).instantiate()
	_world_root().add_child(enemy)
	return enemy


## A bare target at `distance` pixels to the right of the world origin.
func _spawn_target(distance: float) -> Node2D:
	var target := Node2D.new()
	_world_root().add_child(target)
	target.global_position = Vector2(distance, 0.0)
	return target


## Kills an enemy outright, the way a hit harder than its whole health would.
func _kill(enemy: Enemy) -> void:
	var health := enemy.get_node("Health") as Health
	var ctx := DamageContext.new()
	ctx.source = enemy
	ctx.target = enemy
	ctx.base_amount = health.max_health + 1.0
	ctx.final_amount = ctx.base_amount
	ctx.tags.append("melee")
	health.apply_damage(ctx)


## Every enemy in the test world except `original`. A splitter adds its children
## into the dead enemy's own container, which is the world here.
func _enemies_in_world(original: Enemy) -> Array:
	var out: Array = []
	for child in _world_root().get_children():
		if child is Enemy and child != original:
			out.append(child)
	return out


## The split children are added with `call_deferred`, so the tree has to settle
## before they are there.
func _settle() -> void:
	for _i in range(3):
		await get_tree().process_frame


func test_every_variant_carries_the_enemy_contract() -> void:
	for variant in VARIANTS:
		var enemy := _spawn_enemy(variant["scene"])
		assert_that(enemy.scene_file_path).override_failure_message(
			"%s did not come from the scene its row names" % variant["name"]
		).is_equal(variant["scene"])
		for child in REQUIRED_CHILDREN:
			assert_bool(enemy.has_node(child)).override_failure_message(
				"%s is missing %s" % [variant["name"], child]
			).is_true()


func test_every_variant_arms_the_weapons_its_role_says() -> void:
	for variant in VARIANTS:
		var enemy := _spawn_enemy(variant["scene"])
		# A weapon placed in the scene is equipped one idle frame after the
		# enemy enters the tree (`WeaponHolder._ready` defers it so the timer
		# can be attached to a settled parent), so read the loadout after that.
		await get_tree().process_frame
		var contact_count := 0
		var ranged_count := 0
		for weapon in enemy.weapon_holder.weapons:
			if weapon is ContactWeapon:
				contact_count += 1
			elif weapon is ProjectileWeapon:
				ranged_count += 1
		match variant["weapon"]:
			"contact":
				assert_int(contact_count).override_failure_message(
					"%s should be armed with one contact weapon" % variant["name"]
				).is_equal(1)
				assert_int(ranged_count).override_failure_message(
					"%s should not be armed with a ranged weapon" % variant["name"]
				).is_equal(0)
			"ranged":
				assert_int(ranged_count).override_failure_message(
					"%s should be armed with one ranged weapon" % variant["name"]
				).is_equal(1)
				assert_int(contact_count).override_failure_message(
					"%s should not hurt on touch" % variant["name"]
				).is_equal(0)


func test_every_variant_moves_away_from_the_basic_enemy_in_its_direction() -> void:
	for variant in VARIANTS:
		var variant_enemy := _spawn_enemy(variant["scene"])
		var grunt := _spawn_enemy(GRUNT_SCENE)
		if variant.get("tougher_than_grunt", false):
			assert_float(variant_enemy.stats.get_stat("health")).override_failure_message(
				"%s is not tougher than the basic enemy" % variant["name"]
			).is_greater(grunt.stats.get_stat("health"))
		if variant.get("fragile_than_grunt", false):
			assert_float(variant_enemy.stats.get_stat("health")).override_failure_message(
				"%s is not frailer than the basic enemy" % variant["name"]
			).is_less(grunt.stats.get_stat("health"))
		if variant.get("slower_than_grunt", false):
			assert_float(variant_enemy.stats.get_stat("movement_speed")).override_failure_message(
				"%s is not slower than the basic enemy" % variant["name"]
			).is_less(grunt.stats.get_stat("movement_speed"))


func test_every_variant_collider_matches_its_art() -> void:
	# The collider is a circle around the drawn creature, so it has to scale
	# with the art. A bigger sprite wearing the old collider is a wall the
	# player walks straight through, and a collider far larger than the art is
	# a wall the player cannot touch.
	for variant in VARIANTS:
		var enemy := _spawn_enemy(variant["scene"])
		var sprite := enemy.get_node("Node2D/Sprite2D") as Sprite2D
		assert_object(sprite.texture).is_not_null()
		var width := float(sprite.texture.get_width())
		assert_float(enemy.body_radius()).override_failure_message(
			"the collider of %s does not match its drawn creature" % variant["name"]
		).is_between(width * 0.3, width * 0.5)


func test_the_bulwark_hurts_on_touch() -> void:
	var bulwark := _spawn_enemy(BULWARK_SCENE)
	var health := DamageableBody.spawn(_world_root(), bulwark.global_position)

	for _i in range(PHYSICS_FRAMES):
		await get_tree().physics_frame

	assert_float(health.current_health).override_failure_message(
		"the Bulwark did not hurt the body standing in its hitbox"
	).is_less(100.0)


func test_the_bulwark_chases_its_target() -> void:
	var bulwark := _spawn_enemy(BULWARK_SCENE)
	var target := _spawn_target(CHASE_DISTANCE)
	var start_x := bulwark.global_position.x
	bulwark.set_target_position(target)

	for _i in range(CHASE_FRAMES):
		await get_tree().physics_frame

	assert_float(bulwark.global_position.x).override_failure_message(
		"the Bulwark did not close on its target"
	).is_greater(start_x + 1.0)


func test_the_gunner_shoots_from_inside_its_weapons_reach() -> void:
	# The row's whole point is that its threat arrives from a distance, so its
	# firing distance has to sit inside its own weapon's reach. Both numbers
	# are read live: this is a relationship, not a balance value.
	var gunner := _spawn_enemy(GUNNER_SCENE)
	await get_tree().process_frame
	assert_int(gunner.weapon_holder.weapons.size()).override_failure_message(
		"the Gunner has no weapon to shoot with"
	).is_equal(1)
	var stop_distance: float = gunner.behaviour.get("stop_distance")
	assert_float(stop_distance).override_failure_message(
		"the Gunner's firing distance is outside its weapon's reach"
	).is_less_equal(gunner.weapon_holder.weapons[0].get_range_px())


func test_the_gunner_holds_its_firing_distance() -> void:
	var gunner := _spawn_enemy(GUNNER_SCENE)
	var target := _spawn_target(GUNNER_START_DISTANCE)
	gunner.set_target_position(target)
	var stop_distance: float = gunner.behaviour.get("stop_distance")

	for _i in range(GUNNER_FRAMES):
		await get_tree().physics_frame

	var settled := gunner.global_position.distance_to(target.global_position)
	assert_float(settled).override_failure_message(
		"the Gunner did not walk in to its firing distance"
	).is_less(GUNNER_START_DISTANCE)
	assert_float(settled).override_failure_message(
		"the Gunner walked past its firing distance instead of holding it"
	).is_between(stop_distance * 0.8, stop_distance * 1.2)


func test_the_gunner_damages_a_body_at_range() -> void:
	var gunner := _spawn_enemy(GUNNER_SCENE)
	var target_position := Vector2(GUNNER_TARGET_DISTANCE, 0.0)
	var health := DamageableBody.spawn(_world_root(), target_position)
	gunner.set_target_position(health.get_parent())

	for _i in range(SHOOT_FRAMES):
		await get_tree().physics_frame

	assert_float(WeaponTestSupport.health_left(health)).override_failure_message(
		"the Gunner's pistol did not reach the body standing in its reach"
	).is_less(100.0)


func test_a_dead_enemy_stops_firing() -> void:
	# A weapon's firing timer lives on the `WeaponHolder`, not on the enemy, so
	# it keeps ticking after `Enemy._physics_process` returns early for a corpse.
	# Without stopping it, a Gunner fires one last shot from its body.
	var gunner := _spawn_enemy(GUNNER_SCENE)
	await get_tree().process_frame
	assert_int(gunner.weapon_holder.weapons.size()).is_equal(1)
	var weapon: BaseWeapon = gunner.weapon_holder.weapons[0]

	var damage := DamageContext.new()
	damage.target = gunner
	damage.base_amount = gunner.health_node.current_health + 1.0
	damage.final_amount = damage.base_amount
	assert_bool(gunner.health_node.apply_damage(damage)).is_true()

	assert_object(weapon.timer).override_failure_message(
		"the dead Gunner's weapon is still ticking"
	).is_null()
	assert_int(gunner.weapon_holder.weapons.size()).override_failure_message(
		"the dead Gunner still carries its weapon"
	).is_equal(0)


func test_the_slimeling_splits_into_copies_of_itself() -> void:
	var slimeling := _spawn_enemy(SLIMELING_SCENE)
	var splitter := slimeling.get_node_or_null("SplitOnDeath") as SplitOnDeath
	assert_object(splitter).override_failure_message(
		"the Slimeling carries no splitter, so it dies like a grunt"
	).is_not_null()
	var parent_health := slimeling.stats.get_stat("health")
	var parent_radius := slimeling.body_radius()

	_kill(slimeling)
	await _settle()

	var minis := _enemies_in_world(slimeling)
	assert_int(minis.size()).override_failure_message(
		"the Slimeling did not split into its children"
	).is_equal(splitter.split_count)
	for mini_enemy in minis:
		var child := mini_enemy as Enemy
		assert_that(child.scene_file_path).override_failure_message(
			"a Slimeling child is not a Slimeling"
		).is_equal(SLIMELING_SCENE)
		assert_float(child.body_radius()).override_failure_message(
			"a Slimeling child is the same size as its parent"
		).is_less(parent_radius)
		assert_float((child.get_node("Health") as Health).max_health).override_failure_message(
			"a Slimeling child is as tough as its parent"
		).is_less(parent_health)


func test_the_slimelings_minis_do_not_split_again() -> void:
	var slimeling := _spawn_enemy(SLIMELING_SCENE)
	_kill(slimeling)
	await _settle()
	var minis_before := _enemies_in_world(slimeling).size()
	assert_int(minis_before).is_greater(0)

	_kill(_enemies_in_world(slimeling)[0] as Enemy)
	await _settle()

	assert_int(_enemies_in_world(slimeling).size()).override_failure_message(
		"a Slimeling mini split again, so a stage could never end"
	).is_equal(minis_before)


func test_the_game_spawns_every_variant() -> void:
	# The roster only reaches the arena if the game's spawn table names it, so
	# this is the wiring the whole plan hangs on.
	var game: Node = auto_free(load("res://src/Scenes/Game.tscn").instantiate())
	var spawner := game.get_node("StageManager/EnemySpawner") as EnemySpawner
	var spawned: Array[String] = []
	for row in spawner.spawn_table:
		if row.scene != null:
			spawned.append(row.scene.resource_path)
	for variant in VARIANTS:
		assert_bool(variant["scene"] in spawned).override_failure_message(
			"the game's spawn table has no %s row, so the roster never reaches the arena"
			% variant["name"]
		).is_true()
