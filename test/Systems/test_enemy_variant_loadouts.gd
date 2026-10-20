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

## The roster, by row. What each row arms and how it differs from the basic
## enemy is its role, so it belongs here rather than in the assertions.
const VARIANTS := [
	{
		"name": "Bulwark",
		"scene": "res://src/Systems/EnemyBulwark.tscn",
		# It is the contact-damage wall, so it keeps Thorns.
		"arms_contact_weapon": true,
		# It trades its speed for its health. That is the whole row.
		"tougher_than_grunt": true,
		"slower_than_grunt": true,
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

## Physics frames the Bulwark needs to close a visible gap. It walks at a
## fraction of the basic enemy's speed, so it needs a few.
const CHASE_FRAMES := 20

## Where the chase target stands, in pixels, so the enemy has to walk.
const CHASE_DISTANCE := 400.0

var _world: Node2D = null


func after_test() -> void:
	if is_instance_valid(_world):
		_world.free()


## The container the test's actors live in.
func _world_root() -> Node2D:
	if not is_instance_valid(_world):
		_world = Node2D.new()
		_world.name = "World"
		add_child(_world)
	return _world


## An enemy of `scene_path` in the test world.
func _spawn_enemy(scene_path: String) -> Enemy:
	var enemy: Enemy = load(scene_path).instantiate()
	_world_root().add_child(enemy)
	return enemy


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


func test_every_variant_arms_the_contact_weapon_its_role_says() -> void:
	for variant in VARIANTS:
		var enemy := _spawn_enemy(variant["scene"])
		var weapons: Array[BaseWeapon] = enemy.weapon_holder.weapons
		if variant["arms_contact_weapon"]:
			assert_int(weapons.size()).override_failure_message(
				"%s should be armed with one contact weapon" % variant["name"]
			).is_equal(1)
			assert_bool(weapons[0] is ContactWeapon).override_failure_message(
				"%s should be armed with a contact weapon" % variant["name"]
			).is_true()
		else:
			assert_int(weapons.size()).override_failure_message(
				"%s should not be armed with a contact weapon" % variant["name"]
			).is_equal(0)


func test_every_variant_moves_away_from_the_basic_enemy_in_its_direction() -> void:
	for variant in VARIANTS:
		var variant_enemy := _spawn_enemy(variant["scene"])
		var grunt := _spawn_enemy(GRUNT_SCENE)
		if variant["tougher_than_grunt"]:
			assert_float(variant_enemy.stats.get_stat("health")).override_failure_message(
				"%s is not tougher than the basic enemy" % variant["name"]
			).is_greater(grunt.stats.get_stat("health"))
		if variant["slower_than_grunt"]:
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
	var target := Node2D.new()
	_world_root().add_child(target)
	var start_x := bulwark.global_position.x
	target.global_position = Vector2(start_x + CHASE_DISTANCE, 0.0)
	bulwark.set_target_position(target)

	for _i in range(CHASE_FRAMES):
		await get_tree().physics_frame

	assert_float(bulwark.global_position.x).override_failure_message(
		"the Bulwark did not close on its target"
	).is_greater(start_x + 1.0)


func test_the_game_spawns_the_bulwark() -> void:
	# The roster only reaches the arena if the game's spawn table names it, so
	# this is the wiring the whole plan hangs on.
	var game: Node = auto_free(load("res://src/Scenes/Game.tscn").instantiate())
	var spawner := game.get_node("StageManager/EnemySpawner") as EnemySpawner
	var found := false
	for row in spawner.spawn_table:
		if row.scene != null and row.scene.resource_path == BULWARK_SCENE:
			found = true
	assert_bool(found).override_failure_message(
		"the game's spawn table has no Bulwark row, so the roster never reaches the arena"
	).is_true()
