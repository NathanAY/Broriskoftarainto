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

## The aura's reach **in pixels**, which is its `weapon_range`. There is no
## second, hidden radius any more: `weapon_range` is what the selector measures
## against and what the burst draws.
##
## `weapon_range` is authored in meters (see `docs/systems/stats.md`, "Units"),
## but every distance this suite measures is a pixel distance, so the conversion
## happens once here through `Stats`. Read from the weapon rather than hardcoded,
## because it is the number the damage assertions below are actually about.
## `TestScene.tscn` puts its enemy `NEAR_DISTANCE` (200 px) from the character,
## just outside the range (0.66 m = 198 px), and the weapon sprite orbits the
## holder at `weapon_orbit_radius` (0.2 m = 60 px), so the distance the selector
## measures swings between `range - 60` and `range + 60`. That straddles the
## boundary, and the aura then damages the enemy on only part of its orbit - a
## suite that passes or fails depending on the orbit phase.
## `test_damages_an_enemy_in_range` therefore pulls its target well inside.
func _aura_range_px() -> float:
	return Stats.meters_to_px(load(DEATH_AURA).weapon_range)

## Health every target in this suite is raised to.
##
## It cannot be `WeaponTestSupport.ENEMY_HEALTH` (40), which is sized for a
## weapon that lands one hit: the aura ticks twice a second, so a 240-frame
## window at time factor 5 is ~10 ticks, and 8 of them are enough to kill a
## 40-health target. A dead target frees its `Health` node, which turns every
## following assertion into a read on a dangling object. The drop is still the
## assertion, so the budget only has to be comfortably above the damage dealt.
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


## The aura's firing rate is whatever `base_attack_speed` the `.tres` currently
## declares, folded together with the holder's own `attack_speed` stat by
## `BaseWeapon._update_timer_wait` - so the timer waits `1 / (rate x speed)` and
## the holder's speed can retune it at runtime.
##
## **No literal rate is asserted here.** A weapon's numbers are balance data,
## changed in `.tres` by design, so pinning one turns every rebalance into a red
## suite. What has to stay true is the *mechanic*: the timer follows the weapon's
## own rate rather than the `BaseWeapon` default of 1s, and it is derived (the
## product of the two speeds), not authored. So the expectation is computed from
## the values under test, and the proportionality is asserted by doubling the
## rate and checking the wait halves.
##
## Pinned through the live timer rather than only the `.tres`, because
## `_update_timer_wait` is where the two speeds are multiplied together - a
## weapon whose rate was silently ignored there would still pass an assertion
## that only reads the resource.
func test_firing_timer_is_derived_from_the_weapons_own_rate() -> void:
	var runner := scene_runner(WeaponTestSupport.TEST_SCENE)
	var test_scene := runner.scene()
	get_tree().current_scene = test_scene

	var character: Character = test_scene.get_node("Character")
	var equipped := WeaponTestSupport.equip_only_weapon(character, DEATH_AURA)
	@warning_ignore("redundant_await")
	await runner.simulate_frames(2)

	var holder_speed: float = character.get_node("Stats").get_stat("attack_speed")
	var expected := 1.0 / maxf(0.001, equipped.base_attack_speed * holder_speed)
	assert_float(equipped.timer.wait_time).override_failure_message(
		"the firing timer does not wait 1 / (base_attack_speed x attack_speed), "
		+ "so the aura's declared rate is not reaching its timer"
	).is_equal_approx(expected, WAIT_TIME_TOLERANCE)

	# The derivation, not a coincidence: twice the rate, half the wait. A timer
	# hardcoded to a "reasonable" cadence fails here even when the first assertion
	# happens to agree.
	equipped.base_attack_speed *= 2.0
	equipped._update_timer_wait()
	assert_float(equipped.timer.wait_time).override_failure_message(
		"doubling the weapon's rate did not halve its firing timer"
	).is_equal_approx(expected * 0.5, WAIT_TIME_TOLERANCE)

	test_scene.free()


## Slack for firing-timer waits. Both sides are the same float division, but the
## assertion runs after the weapon has been re-equipped and the stat read
## separately, so exact equality is not guaranteed by anything.
const WAIT_TIME_TOLERANCE := 0.001


func test_damages_an_enemy_in_range() -> void:
	var runner := scene_runner(WeaponTestSupport.TEST_SCENE)
	var test_scene := runner.scene()
	runner.set_time_factor(5)
	get_tree().current_scene = test_scene

	var enemy: Enemy = test_scene.get_node("Enemy")
	var character: Character = test_scene.get_node("Character")
	# Well inside the radius, so the orbiting sprite cannot carry the measured
	# distance past it. See `_aura_radius`.
	enemy.global_position = character.global_position + Vector2(NEAR_DISTANCE * 0.4, 0.0)
	var e_health := _give_health(enemy)

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
	var character: Character = test_scene.get_node("Character")
	# Both targets close in, on opposite sides, so both are inside the radius at
	# every point of the sprite's orbit. See `_aura_radius`.
	enemy.global_position = character.global_position + Vector2(NEAR_DISTANCE * 0.4, 0.0)
	var behind := WeaponTestSupport.spawn_enemy_behind(
		test_scene, enemy, Vector2(0, -NEAR_DISTANCE * 0.4))
	var near_health := _give_health(enemy)
	var far_health := _give_health(behind)

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
##
## Measured from the character rather than the scene enemy, and placed past the
## range by more than `weapon_orbit_radius`, so the orbiting sprite cannot bring
## it back inside.
func test_leaves_an_enemy_beyond_its_range_untouched() -> void:
	var runner := scene_runner(WeaponTestSupport.TEST_SCENE)
	var test_scene := runner.scene()
	runner.set_time_factor(5)
	get_tree().current_scene = test_scene

	var enemy: Enemy = test_scene.get_node("Enemy")
	var character: Character = test_scene.get_node("Character")
	# past the aura's reach, so the selector must never return it
	var distant := WeaponTestSupport.spawn_enemy_behind(
		test_scene, enemy, Vector2(0, _aura_range_px() + 200.0))
	var d_health := _give_health(distant)

	WeaponTestSupport.equip_only_weapon(character, DEATH_AURA)

	@warning_ignore("redundant_await")
	await runner.simulate_frames(WeaponTestSupport.FRAMES)

	assert_float(WeaponTestSupport.health_left(d_health)).override_failure_message(
		"an enemy beyond the aura's range was damaged").is_equal(TARGET_HEALTH)

	test_scene.free()


## A burst is placed on the weapon's sprite and sized to the weapon's range.
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
	# `burst.radius` is pixels - `AreaWeapon` hands the burst `get_range_px()` -
	# so the expectation is the weapon's own pixel accessor, not the meter value.
	assert_float(burst.radius).override_failure_message(
		"the burst does not match the weapon's weapon_range, so it draws a "
		+ "circle the damage does not reach").is_equal(aura.get_range_px())
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
##
## The target is raised to [constant TARGET_HEALTH] and pulled well inside the
## range, because `BaseWeapon._on_timeout` only calls `try_shoot` - and so only
## spawns a burst - when the selector finds something within `weapon_range`.
## `TestScene.tscn`'s enemy sits on `NEAR_DISTANCE` (200 px, just outside the
## 198 px range), which straddles the orbit boundary and would spawn a burst on
## only part of the orbit; the default 10 health would then be killed by two
## ticks, after which a freed enemy stops being a target and every later tick
## spawns nothing.
func test_the_timer_spawns_a_burst_per_tick() -> void:
	var runner := scene_runner(WeaponTestSupport.TEST_SCENE)
	var test_scene := runner.scene()
	runner.set_time_factor(5)
	get_tree().current_scene = test_scene

	var character: Character = test_scene.get_node("Character")
	var enemy: Enemy = test_scene.get_node("Enemy")
	# well inside the range, so the orbiting sprite cannot carry it outside on
	# any tick (see `_aura_range_px`)
	enemy.global_position = character.global_position + Vector2(NEAR_DISTANCE * 0.4, 0.0)
	_give_health(enemy)
	var aura := WeaponTestSupport.equip_only_weapon(character, DEATH_AURA)
	@warning_ignore("redundant_await")
	await runner.simulate_frames(2)
	_record_bursts(character)

	# The window is derived from the aura's own `wait_time`, not the shared
	# `WeaponTestSupport.FRAMES`, because the firing `Timer` counts *unscaled*
	# time - `set_time_factor` above does not stretch it. So 240 frames is ~4s
	# regardless, which at half rate spans two ticks and lands on one whenever
	# the window closes on a boundary. Six ticks of headroom keeps "and keeps
	# reaching it" true whatever the rate is set to next.
	@warning_ignore("redundant_await")
	await runner.simulate_frames(int(aura.timer.wait_time * 60.0 * 6.0))

	# the aura ticks every two seconds, so this window covers ~6 ticks. The exact
	# count is left to the damage suites; what matters here is that the timer
	# reaches the spawn path at all and keeps reaching it.
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
	# a second aura at a clearly different range, so a shared material shows up
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
	).is_equal_approx(aura.get_range_px() * AreaDamageBurst.START_FRACTION, RADIUS_TOLERANCE)
	assert_float(_rim_radius(last)).override_failure_message(
		"the second weapon's burst drew the first weapon's range"
	).is_equal_approx(second.get_range_px() * AreaDamageBurst.START_FRACTION, RADIUS_TOLERANCE)

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