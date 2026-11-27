# The Miner and his MinerMineModifier: weapons hold fire, ranged only, and a mine
# every `lay_interval` carrying the shots the weapons would have fired. Every
# expectation is derived from the weapon under test and the `miner_mine` config
# block, never from a literal.
class_name MinerTest
extends GdUnitTestSuite

const MINER := "res://src/Assets/character/miner/Miner.tres"
const MINE_MODIFIER := "res://src/Systems/Items/modifiers/MinerMineModifier.tscn"
const PISTOL := "res://src/Resources/weapons/Pistol.tres"
const SHOTGUN := "res://src/Resources/weapons/Shotgun.tres"
const SMG := "res://src/Resources/weapons/Smg.tres"
const MELEE := ["res://src/Resources/weapons/Fist.tres", "res://src/Resources/weapons/DeathAura.tres",
		"res://src/Resources/weapons/Thorns.tres"]


func _scene() -> Node:
	var runner := scene_runner(WeaponTestSupport.TEST_SCENE)
	var test_scene := runner.scene()
	get_tree().current_scene = test_scene
	return test_scene


func _make_miner(test_scene: Node) -> Character:
	var character: Character = test_scene.get_node("Character")
	for weapon in character.weapon_holder.weapons.duplicate():
		character.weapon_holder.remove_weapon(weapon)
	BaseModifier.attach(load(MINE_MODIFIER), character.item_holder, character.event_manager)
	return character


func _modifier(character: Character) -> Node:
	return character.item_holder.get_node("MinerMineModifier")


func _projectiles(test_scene: Node) -> Array:
	return test_scene.get_children().filter(func(n): return n is Projectile)


func _cfg(key: String) -> float:
	return float(GameConfig.section("miner_mine").get(key, 0.0))


func _attacks_per_mine(weapon: ProjectileWeapon, stats: Stats) -> float:
	return weapon.attack_speed_with(stats) * _cfg("lay_interval")


# --- Ranged only ----------------------------------------------------------------


func test_miner_takes_ranged_weapons_and_refuses_the_rest() -> void:
	var test_scene := _scene()
	var holder := _make_miner(test_scene).weapon_holder
	for path in MELEE:
		assert_bool(holder.can_add_weapon(load(path))).override_failure_message("%s was accepted" % path).is_false()
		assert_bool(holder.add_weapon(load(path))).is_false()
	assert_int(holder.weapons.size()).is_equal(0)
	for path in [PISTOL, SHOTGUN, SMG]:
		assert_bool(holder.add_weapon(load(path))).override_failure_message("%s was refused" % path).is_true()
	assert_int(holder.weapons.size()).is_equal(3)
	test_scene.free()


func test_miner_kit_starts_with_a_ranged_weapon_and_the_mine() -> void:
	var data: CharacterData = load(MINER)
	assert_bool(data.starting_weapons.all(func(w): return w is ProjectileWeapon)).is_true()
	assert_object(data.starting_weapons[0]).is_instanceof(ShotgunWeapon)
	assert_bool(data.modifiers.has(load(MINE_MODIFIER))).is_true()


# --- Weapons hold fire ----------------------------------------------------------


func test_miner_weapons_do_not_fire_on_their_own() -> void:
	var test_scene := _scene()
	var character: Character = test_scene.get_node("Character")
	var pistol := WeaponTestSupport.equip_only_weapon(character, PISTOL)
	pistol._on_timeout()
	assert_int(_projectiles(test_scene).size()).override_failure_message(
		"control: an ordinary pistol in range should fire").is_equal(1)
	for p in _projectiles(test_scene):
		p.free()

	BaseModifier.attach(load(MINE_MODIFIER), character.item_holder, character.event_manager)
	pistol._on_timeout()
	assert_int(_projectiles(test_scene).size()).is_equal(0)
	test_scene.free()


func test_detaching_the_mine_gives_the_holder_back() -> void:
	var test_scene := _scene()
	var character := _make_miner(test_scene)
	_modifier(character).detach()
	assert_bool(character.weapon_holder.hold_fire).is_false()
	assert_bool(character.weapon_holder.add_weapon(load(MELEE[0]))).is_true()
	test_scene.free()


# --- Laying -----------------------------------------------------------------------


func test_a_mine_packs_what_each_weapon_would_fire_in_the_interval() -> void:
	var test_scene := _scene()
	var character := _make_miner(test_scene)
	character.weapon_holder.add_weapon(load(PISTOL))
	character.weapon_holder.add_weapon(load(SHOTGUN))
	var mine: Mine = _modifier(character).lay_mine()

	assert_object(mine).is_not_null()
	assert_vector(mine.global_position).is_equal(character.global_position)
	assert_int(mine.charges.size()).is_equal(2)
	for charge in mine.charges:
		var weapon: ProjectileWeapon = charge[0]
		var attacks := floori(_attacks_per_mine(weapon, character.stats))
		assert_int(charge[1]).is_equal(attacks * weapon.projectiles_per_attack())
	test_scene.free()


## A shotgun packs whole volleys: every mine holds a multiple of its pellets.
func test_a_shotgun_mine_holds_whole_volleys() -> void:
	var test_scene := _scene()
	var character := _make_miner(test_scene)
	character.weapon_holder.add_weapon(load(SHOTGUN))
	var shotgun: ProjectileWeapon = character.weapon_holder.weapons[0]
	var modifier := _modifier(character)
	for i in 6:
		var mine: Mine = modifier.lay_mine()
		if mine != null:
			assert_int(mine.charges[0][1] % shotgun.projectiles_per_attack()).is_equal(0)
	test_scene.free()


## The user's example: a weapon attacking every 1.2 s. The first mine gets the
## one attack finished inside its window and carries the 0.8 s already charged,
## so the next mine gets two. Each mine must hold exactly the attacks that
## complete inside its own window of the timeline (1, 2, 2 with 2 s mines).
func test_unfinished_attacks_carry_into_the_next_mine() -> void:
	var test_scene := _scene()
	var character := _make_miner(test_scene)
	character.weapon_holder.add_weapon(load(PISTOL))
	var weapon: ProjectileWeapon = character.weapon_holder.weapons[0]
	var period := 1.2
	weapon.base_attack_speed = 1.0 / (period * character.stats.get_stat("attack_speed"))
	var interval := _cfg("lay_interval")
	var modifier := _modifier(character)
	var counts: Array[int] = []
	for k in range(1, 6):
		var expected := floori(k * interval / period + 0.000001) - floori((k - 1) * interval / period + 0.000001)
		var mine: Mine = modifier.lay_mine()
		var packed: int = mine.charges[0][1] if mine != null else 0
		assert_int(packed).override_failure_message("mine %d packed %d, the timeline finishes %d attacks in its window" % [k, packed, expected]).is_equal(expected)
		counts.append(packed)
	if is_equal_approx(interval, 2.0):
		assert_array(counts.slice(0, 2)).is_equal([1, 2])
	test_scene.free()


func test_mines_are_capped() -> void:
	var test_scene := _scene()
	var character := _make_miner(test_scene)
	character.weapon_holder.add_weapon(load(SMG))
	var modifier := _modifier(character)
	var cap := int(_cfg("max_mines"))
	for i in cap + 3:
		modifier.lay_mine()
	await get_tree().process_frame
	var alive := test_scene.get_children().filter(func(n): return n is Mine)
	assert_int(alive.size()).is_equal(cap)
	test_scene.free()


# --- Detonation -------------------------------------------------------------------


func test_detonation_fires_every_packed_shot_in_random_directions_at_bonus_damage() -> void:
	var test_scene := _scene()
	var character := _make_miner(test_scene)
	character.weapon_holder.add_weapon(load(SMG))
	var weapon: ProjectileWeapon = character.weapon_holder.weapons[0]
	var mine: Mine = _modifier(character).lay_mine()
	var packed: int = mine.charges[0][1]
	mine.global_position = Vector2(-500, -500)  # away from every body

	mine.detonate()

	var shots := _projectiles(test_scene)
	assert_int(shots.size()).is_equal(packed)
	var directions := {}
	for p in shots:
		assert_float(p.damage).is_equal_approx(weapon.current_damage * _cfg("damage_multiplier"), 0.0001)
		assert_vector(p.global_position).is_equal(mine.global_position)
		directions[snappedf(p.direction.angle(), 0.01)] = true
	assert_int(directions.size()).override_failure_message("every shot flew the same way").is_greater(1)
	test_scene.free()


func test_an_enemy_stepping_on_the_mine_sets_it_off() -> void:
	var runner := scene_runner(WeaponTestSupport.TEST_SCENE)
	var test_scene := runner.scene()
	get_tree().current_scene = test_scene
	var character := _make_miner(test_scene)
	character.weapon_holder.add_weapon(load(PISTOL))
	var enemy: Enemy = test_scene.get_node("Enemy")
	WeaponTestSupport.give_enemy_health(enemy)
	var mine: Mine = _modifier(character).lay_mine()
	mine.global_position = enemy.global_position

	@warning_ignore("redundant_await")
	await runner.simulate_frames(10)

	assert_bool(is_instance_valid(mine)).override_failure_message("the mine never went off").is_false()
	test_scene.free()


func test_minefield_is_never_a_generated_item() -> void:
	var factory: ItemFactory = auto_free(load("res://src/Systems/Items/ItemFactory.tscn").instantiate())
	add_child(factory)
	factory.rng.seed = 11
	for i in range(300):
		var item: Item = factory.get_item_by_type("effect")
		for scene in item.effect_scene:
			assert_str(scene.resource_path).is_not_equal(MINE_MODIFIER)


## Laying a mine plays one of the lay clips; the scene must ship them, or the
## Miner lays silently with no error.
func test_the_minefield_ships_its_lay_sounds() -> void:
	var modifier: Node = auto_free(load(MINE_MODIFIER).instantiate())
	var sounds: Array = modifier.lay_sounds
	assert_bool(sounds.is_empty()).is_false()
	for sound in sounds:
		assert_object(sound).is_instanceof(AudioStream)


## The drawn mine and the trigger circle come from the same radius, so what the
## player sees is exactly what an enemy has to touch.
func test_the_mine_is_drawn_as_wide_as_its_trigger() -> void:
	var test_scene := _scene()
	var character := _make_miner(test_scene)
	character.weapon_holder.add_weapon(load(SMG))
	var mine: Mine = _modifier(character).lay_mine()
	var sprite: Sprite2D = mine.get_node("Sprite2D")
	var trigger: CircleShape2D = (mine.get_child(0) as CollisionShape2D).shape
	assert_float(sprite.texture.get_width() * sprite.scale.x).is_equal_approx(trigger.radius * 2.0, 0.01)
	assert_float(trigger.radius).is_equal_approx(Stats.meters_to_px(_cfg("trigger_radius")), 0.01)
	test_scene.free()
