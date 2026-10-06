# The Death Aura is the project's only `AreaWeapon`. Its behaviour comes
# entirely from `AllTargetsInRangeSelector`: every `damageable` node within
# `weapon_range` of the weapon's own sprite, on every timer tick. There is no
# picked target and no impact point, which is why the visual is a ring rather
# than a hit spark - so these suites pin *both* halves: who gets hit, and what
# the player is shown.
class_name DeathAuraTest
extends GdUnitTestSuite

const DEATH_AURA := "res://src/Resources/weapons/DeathAura.tres"
const BURST_SCENE := "res://src/Scenes/particles/area_damage_burst.tscn"

## Distance from the character to the near enemy in `TestScene.tscn`.
const NEAR_DISTANCE := 200.0

## Health every target in this suite is raised to.
##
## It cannot be `WeaponTestSupport.ENEMY_HEALTH` (40), which is sized for a
## weapon that lands one hit: the aura fires every second, so a 240-frame window
## at time factor 5 is ~20 ticks, and 8 of them are enough to kill a 40-health
## target. A dead target frees its `Health` node, which turns every following
## assertion into a read on a dangling object. The drop is still the assertion,
## so the budget only has to be comfortably above the damage dealt.
const TARGET_HEALTH := 1000.0

## Bursts seen since the last `_record_bursts`. Reset by that call, so each test
## starts from an empty list without having to thread one through every assert.
var spawned_bursts: Array[AreaDamageBurst] = []


## The shipped resource must still be an `AreaWeapon` aimed at *all* targets.
## Renaming the file is easy to get half-done, and a stray `closest.tres` here
## would silently turn the aura back into a single-target weapon while every
## damage assertion below still passed.
func test_resource_is_an_area_weapon_aiming_at_everything() -> void:
	var aura := load(DEATH_AURA)
	assert_that(aura).is_instanceof(AreaWeapon)
	assert_that(aura.name).is_equal("DeathAura")
	assert_that(aura.target_selector).is_instanceof(AllTargetsInRangeSelector)


func test_damages_an_enemy_in_range() -> void:
	var runner := scene_runner(WeaponTestSupport.TEST_SCENE)
	var test_scene := runner.scene()
	runner.set_time_factor(5)
	get_tree().current_scene = test_scene

	var enemy: Enemy = test_scene.get_node("Enemy")
	var e_health := _give_health(enemy)
	var character: Character = test_scene.get_node("Character")

	WeaponTestSupport.equip_only_weapon(character, DEATH_AURA)

	@warning_ignore("redundant_await")
	await runner.simulate_frames(WeaponTestSupport.FRAMES)

	var left := WeaponTestSupport.health_left(e_health)
	assert_float(left).override_failure_message(
		"the enemy died and freed its Health node").is_greater(0.0)
	assert_float(left).override_failure_message(
		"the aura dealt no damage to an enemy well inside its range").is_less(
		TARGET_HEALTH)

	test_scene.free()


## The defining property of an aura: two enemies on opposite sides are both hit
## in the same tick. A selector that returned one target would leave the far one
## at full health, so this is the assertion that separates an aura from a
# projectile or a single-swing weapon.
func test_damages_every_enemy_in_range_in_one_tick() -> void:
	var runner := scene_runner(WeaponTestSupport.TEST_SCENE)
	var test_scene := runner.scene()
	runner.set_time_factor(5)
	get_tree().current_scene = test_scene

	var enemy: Enemy = test_scene.get_node("Enemy")
	var behind := WeaponTestSupport.spawn_enemy_behind(
		test_scene, enemy, Vector2(0, NEAR_DISTANCE * 0.8))
	var near_health := _give_health(enemy)
	var far_health := _give_health(behind)
	var character: Character = test_scene.get_node("Character")

	WeaponTestSupport.equip_only_weapon(character, DEATH_AURA)

	@warning_ignore("redundant_await")
	await runner.simulate_frames(WeaponTestSupport.FRAMES)

	var near_left := WeaponTestSupport.health_left(near_health)
	var far_left := WeaponTestSupport.health_left(far_health)
	assert_float(near_left).override_failure_message(
		"the near enemy died and freed its Health node").is_greater(0.0)
	assert_float(far_left).override_failure_message(
		"the far enemy died and freed its Health node").is_greater(0.0)
	assert_float(near_left).override_failure_message(
		"the near enemy was not damaged").is_less(TARGET_HEALTH)
	assert_float(far_left).override_failure_message(
		"the aura only reached one target - it is not hitting everything in range"
	).is_less(TARGET_HEALTH)

	test_scene.free()


## The other half of "in range": a target beyond `weapon_range` must be left
## alone. Without this the previous test would also pass for a weapon that
## simply damages the whole scene.
func test_leaves_an_enemy_beyond_its_range_untouched() -> void:
	var runner := scene_runner(WeaponTestSupport.TEST_SCENE)
	var test_scene := runner.scene()
	runner.set_time_factor(5)
	get_tree().current_scene = test_scene

	var enemy: Enemy = test_scene.get_node("Enemy")
	# past the aura's own weapon_range, so the selector must never return it
	var distant := WeaponTestSupport.spawn_enemy_behind(
		test_scene, enemy, Vector2(0, load(DEATH_AURA).weapon_range + 200.0))
	var d_health := _give_health(distant)
	var character: Character = test_scene.get_node("Character")

	WeaponTestSupport.equip_only_weapon(character, DEATH_AURA)

	@warning_ignore("redundant_await")
	await runner.simulate_frames(WeaponTestSupport.FRAMES)

	assert_float(WeaponTestSupport.health_left(d_health)).override_failure_message(
		"an enemy beyond weapon_range was damaged").is_equal(TARGET_HEALTH)

	test_scene.free()


## A burst is placed on the weapon's sprite and sized to `weapon_range`.
##
## The sprite is the origin `AllTargetsInRangeSelector` measures from, so
## putting the visual anywhere else would draw a circle the damage does not
## match - and because the sprite orbits the holder, that offset is up to
## `weapon_orbit_radius` away from the character itself.
##
## `try_shoot` is driven directly rather than waiting on the weapon's timer:
## the burst frees itself ~0.6s after it spawns, so however long a simulated
## window is chosen, the frames sampled at its end may well fall in the gap
## between two bursts. The timer path is covered by
## `test_the_timer_spawns_a_burst_per_tick`.
func test_a_tick_places_its_burst_on_the_weapon_sprite() -> void:
	var runner := scene_runner(WeaponTestSupport.TEST_SCENE)
	var test_scene := runner.scene()
	get_tree().current_scene = test_scene

	var character: Character = test_scene.get_node("Character")
	var aura := WeaponTestSupport.equip_only_weapon(character, DEATH_AURA)
	# one frame, so the sprite exists at its orbit position before the tick
	@warning_ignore("redundant_await")
	await runner.simulate_frames(2)

	_record_bursts(character)
	aura.try_shoot(_one(test_scene.get_node("Enemy")))

	assert_int(spawned_bursts.size()).override_failure_message(
		"the aura tick spawned no damage burst").is_equal(1)

	var burst := spawned_bursts[0]
	assert_float(burst.radius).override_failure_message(
		"the burst does not match the weapon's weapon_range, so it draws a "
		+ "circle the damage does not reach").is_equal(aura.weapon_range)
	assert_vector(burst.global_position).override_failure_message(
		"the burst is not centred on the weapon sprite the selector measures from"
	).is_equal(aura.sprite_node.global_position)
	# and not on the character, which is what the offset exists to catch
	assert_vector(burst.global_position).override_failure_message(
		"the burst was placed on the character instead of the orbiting sprite"
	).is_not_equal(character.global_position)

	test_scene.free()


## The firing timer, not just a direct call, spawns one burst per tick.
##
## Counted through `child_entered_tree` rather than by looking at the children
## afterwards: a burst is gone within ~0.6s, so the child list only proves
## something happened if the sample lands inside a burst's life.
func test_the_timer_spawns_a_burst_per_tick() -> void:
	var runner := scene_runner(WeaponTestSupport.TEST_SCENE)
	var test_scene := runner.scene()
	runner.set_time_factor(5)
	get_tree().current_scene = test_scene

	var character: Character = test_scene.get_node("Character")
	WeaponTestSupport.equip_only_weapon(character, DEATH_AURA)
	_record_bursts(character)

	@warning_ignore("redundant_await")
	await runner.simulate_frames(WeaponTestSupport.FRAMES)

	# the aura ticks once a second, so a 4s window covers several ticks. The
	# exact count is left to the damage suites; what matters here is that the
	# timer reaches the spawn path at all and keeps reaching it.
	assert_int(spawned_bursts.size()).override_failure_message(
		"the weapon timer fired without spawning any damage burst").is_greater(1)

	test_scene.free()


## Two bursts must not share one `process_material`.
##
## `ParticleProcessMaterial` is a sub-resource of the `PackedScene`, so every
## instance gets the *same* object. Writing the ring radius onto it would make
## the second weapon in a run inherit the first one's range, and would write
## that range back to the scene on disk the next time the scene is saved.
func test_bursts_do_not_share_their_process_material() -> void:
	var runner := scene_runner(WeaponTestSupport.TEST_SCENE)
	var test_scene := runner.scene()
	get_tree().current_scene = test_scene

	var character: Character = test_scene.get_node("Character")
	var aura := WeaponTestSupport.equip_only_weapon(character, DEATH_AURA)
	# a second aura at a clearly different radius, so a shared material shows up
	# as one of the two bursts drawing the other's circle
	var second_template := load(DEATH_AURA).duplicate(true)
	second_template.weapon_range = aura.weapon_range * 2.0
	character.weapon_holder.add_weapon(second_template)
	@warning_ignore("redundant_await")
	await runner.simulate_frames(2)
	# `add_weapon` duplicates the resource it is given, so the template above is
	# not the equipped instance; the live one is the last entry.
	var second: AreaWeapon = character.weapon_holder.weapons[-1]
	assert_float(second.weapon_range).override_failure_message(
		"the second aura did not keep its own range").is_equal(
		aura.weapon_range * 2.0)

	_record_bursts(character)
	var enemy: Node = test_scene.get_node("Enemy")
	aura.try_shoot(_one(enemy))
	second.try_shoot(_one(enemy))

	assert_int(spawned_bursts.size()).is_equal(2)
	var first := spawned_bursts[0].get_node("Rim") as GPUParticles2D
	var last := spawned_bursts[1].get_node("Rim") as GPUParticles2D
	
	assert_object(first.process_material).override_failure_message(
		"two bursts share one ParticleProcessMaterial, so the second weapon's "
		+ "range overwrites the first's").is_not_same(
		last.process_material)
	# The ring is emitted partway out and the shards carry it the rest of the way
	# (see AreaDamageBurst.START_FRACTION), so the contract is proportional to
	# weapon_range rather than equal to it. Checking the raw ring radius against
	# weapon_range would pin the authored authoring choice instead of the scaling.
	assert_float(_rim_radius(first)).override_failure_message(
		"the rim shards were not scaled to the weapon's own range"
	).is_equal_approx(aura.weapon_range * AreaDamageBurst.START_FRACTION, RADIUS_TOLERANCE)
	assert_float(_rim_radius(last)).override_failure_message(
		"the second weapon's burst drew the first weapon's radius"
	).is_equal_approx(second.weapon_range * AreaDamageBurst.START_FRACTION, RADIUS_TOLERANCE)

	test_scene.free()


## A burst frees itself once its particles are gone.
##
## It is spawned on every tick of every aura, so one that outlives its effect
## accumulates for the length of a run.
func test_burst_frees_itself_after_its_particles_finish() -> void:
	var runner := scene_runner(WeaponTestSupport.TEST_SCENE)
	var test_scene := runner.scene()
	get_tree().current_scene = test_scene

	var character: Character = test_scene.get_node("Character")
	WeaponTestSupport.equip_only_weapon(character, DEATH_AURA)

	var burst: Node = load(BURST_SCENE).instantiate()
	character.add_child(burst)

	@warning_ignore("redundant_await")
	await runner.simulate_frames(90)

	assert_bool(is_instance_valid(burst)).override_failure_message(
		"the burst outlived its particles and is leaking a node per tick").is_false()

	test_scene.free()


## Slack for comparing particle radii. `ParticleProcessMaterial` stores its
## emission radii as 32-bit floats while GDScript computes the expected value in
## 64-bit, so `400.0 * 0.55` reads back as 220.0 and compares unequal to the
## 220.00000000000003 it was set from. Exact `is_equal` can never pass here.
const RADIUS_TOLERANCE := 0.001

## The radius the burst's rim shards are emitted on. Not the aura's full range:
## `AreaDamageBurst.START_FRACTION` of the way out, with the rest travelled.
func _rim_radius(emitter: GPUParticles2D) -> float:
	return (emitter.process_material as ParticleProcessMaterial).emission_ring_radius


## Raises `enemy` to [constant TARGET_HEALTH] through its `Stats`, so the health
## bar agrees with `current_health`, and returns the `Health` node.
## `WeaponTestSupport`'s version hardcodes its own, much smaller budget.
func _give_health(enemy: Enemy) -> Health:
	var health: Health = enemy.get_node("Health")
	enemy.get_node("Stats").set_base_stat("health", TARGET_HEALTH)
	health.max_health = TARGET_HEALTH
	health.current_health = TARGET_HEALTH
	return health


## A one-element `Array[Node]`, the shape `try_shoot` declares. A bare literal
## is an untyped `Array` and is rejected at the call.
func _one(node: Node) -> Array[Node]:
	var single: Array[Node] = [node]
	return single


## Starts recording every `AreaDamageBurst` parented under `node`, appending
## them to [member spawned_bursts].
##
## Recorded through the signal rather than by reading the child list afterwards
## because a burst frees itself ~0.6s after spawning: by the end of any
## simulated window the list is almost always empty.
func _record_bursts(node: Node) -> void:
	spawned_bursts.clear()
	node.child_entered_tree.connect(_on_burst_entered)


func _on_burst_entered(child: Node) -> void:
	if child is AreaDamageBurst:
		spawned_bursts.append(child)