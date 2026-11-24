extends GdUnitTestSuite

const DEATH_MARK := preload("res://src/Systems/damage/DeathMark.tscn")
const RUNS := 60


func _mark(tint: DeathMark.Tint, width: float) -> DeathMark:
	var mark: DeathMark = auto_free(DEATH_MARK.instantiate())
	mark.setup(tint, width)
	return mark


## The catalogue entry a mark was built from.
func _decal_of(mark: DeathMark) -> Dictionary:
	for decal: Dictionary in DeathMark.decals():
		if decal.texture == mark.texture and decal.frame == mark.frame:
			return decal
	return {}


## Every png in the folder is read as a sheet, a cell at a time.
func test_every_sheet_in_the_folder_is_catalogued() -> void:
	var sheets := {}
	for decal: Dictionary in DeathMark.decals():
		sheets[decal.texture.resource_path] = true
		assert_int(decal.frame).is_between(0, DeathMark.GRID * DeathMark.GRID - 1)
	var pngs := 0
	for file_name in ResourceLoader.list_directory(DeathMark.SHEET_DIR):
		if file_name.get_extension() == "png":
			pngs += 1
	assert_int(sheets.size()).is_equal(pngs)


## The coloured sheet is read as coloured and the generic ones are not: the
## colours are measured, not listed.
func test_colours_are_measured_from_the_cells() -> void:
	var coloured := {}
	for decal: Dictionary in DeathMark.decals():
		var from_generic: bool = decal.texture.resource_path.contains("generic_decals")
		if from_generic:
			assert_int(decal.tint).is_equal(DeathMark.Tint.NONE)
		elif decal.tint != DeathMark.Tint.NONE:
			coloured[decal.tint] = true
	for tint in [DeathMark.Tint.RED, DeathMark.Tint.GREEN, DeathMark.Tint.PURPLE]:
		assert_bool(coloured.has(tint)).is_true()


## Marks must differ from each other, or they read as one stamp.
func test_marks_vary() -> void:
	var looks := {}
	for i in RUNS:
		var mark := _mark(DeathMark.Tint.NONE, 80.0)
		looks["%s/%d" % [mark.texture.resource_path, mark.frame]] = true
	assert_int(looks.size()).is_greater(8)


## The art has a fixed light direction, so tilt stays within +-15 degrees, and
## it is really used (not always upright).
func test_tilt_is_limited() -> void:
	var tilts := {}
	for i in RUNS:
		var mark := _mark(DeathMark.Tint.NONE, 80.0)
		assert_float(rad_to_deg(mark.rotation)).is_between(-DeathMark.MAX_TILT_DEG, DeathMark.MAX_TILT_DEG)
		tilts[snappedf(mark.rotation, 0.001)] = true
	assert_int(tilts.size()).is_greater(1)


## An enemy with no tint never gets a coloured decal.
func test_untinted_enemy_gets_only_generic_decals() -> void:
	for i in RUNS:
		assert_int(_decal_of(_mark(DeathMark.Tint.NONE, 80.0)).tint).is_equal(DeathMark.Tint.NONE)


## A tinted enemy gets both kinds, so it is not the same stain every time, and a
## coloured decal is only ever of its own colour.
func test_tinted_enemy_mixes_coloured_and_generic() -> void:
	var coloured := 0
	for i in 200:
		var tint: DeathMark.Tint = _decal_of(_mark(DeathMark.Tint.GREEN, 80.0)).tint
		assert_bool(tint == DeathMark.Tint.NONE or tint == DeathMark.Tint.GREEN).is_true()
		if tint == DeathMark.Tint.GREEN:
			coloured += 1
	assert_int(coloured).is_between(1, 199)


## The tint comes from the sprite's own colour, so no enemy scene needs setting up.
func test_tint_is_read_from_the_sprite() -> void:
	var expected := {
		"spitter": DeathMark.Tint.PURPLE,
		"swarmer": DeathMark.Tint.PURPLE,
		"slimeling": DeathMark.Tint.GREEN,
		"toadstinker": DeathMark.Tint.NONE,
		"gunner": DeathMark.Tint.NONE,
		"shieldbearer": DeathMark.Tint.NONE,
	}
	for enemy: String in expected:
		var art := load("res://src/Assets/enemies/%s.png" % enemy) as Texture2D
		assert_int(DeathMark.tint_of(art, true)).is_equal(expected[enemy])
	assert_int(DeathMark.tint_of(null)).is_equal(DeathMark.Tint.NONE)


## Reading a tint never blocks: a sprite whose scan has not finished reads as
## `NONE`, and the finished answer is the same one the blocking read gives.
func test_tint_scan_runs_in_the_background() -> void:
	var art := load("res://src/Assets/enemies/slimeling.png") as Texture2D
	DeathMark.request_tint(art)
	var early := DeathMark.tint_of(art)
	assert_bool(early == DeathMark.Tint.NONE or early == DeathMark.Tint.GREEN).is_true()
	assert_int(DeathMark.tint_of(art, true)).is_equal(DeathMark.Tint.GREEN)
	assert_int(DeathMark.tint_of(art)).is_equal(DeathMark.Tint.GREEN)


## The boss leaves a corpse like any other enemy.
func test_boss_leaves_a_corpse() -> void:
	var scene: Node = auto_free(Node.new())
	var marks := Node.new()
	marks.name = "death_marks"
	var nodes := Node.new()
	nodes.name = "Nodes"
	nodes.add_child(marks)
	scene.add_child(nodes)
	get_tree().root.add_child(scene)
	var previous := get_tree().current_scene
	get_tree().current_scene = scene
	var boss: Enemy = auto_free(load("res://src/Systems/enemies/EnemyBoss.tscn").instantiate())
	scene.add_child(boss)
	boss.global_position = Vector2(300, 200)
	DeathMark.leave_corpse(boss)
	await get_tree().process_frame
	get_tree().current_scene = previous
	assert_int(marks.get_child_count()).is_equal(1)
	assert_vector((marks.get_child(0) as Node2D).global_position).is_equal(Vector2(300, 200))


## `BossSpawner` hooks the boss's death, so killing the spawned boss leaves a decal.
func test_spawned_boss_leaves_a_corpse_on_death() -> void:
	var root: Node = auto_free(Node.new())
	get_tree().root.add_child(root)
	var nodes := Node.new()
	nodes.name = "Nodes"
	root.add_child(nodes)
	var enemies := Node.new()
	enemies.name = "Enemies"
	nodes.add_child(enemies)
	var marks := Node.new()
	marks.name = "death_marks"
	nodes.add_child(marks)
	var phase := Node.new()
	phase.name = "StageManager"
	root.add_child(phase)
	var character: Character = auto_free(load("res://src/Systems/Character.tscn").instantiate())
	root.add_child(character)
	var spawner: BossSpawner = auto_free(load("res://src/Systems/BossSpawner.tscn").instantiate())
	spawner.character = character
	spawner.spawn_telegraph_time = 0.0 # the test reads the boss straight after the call
	phase.add_child(spawner)
	spawner.spawn_boss()

	var previous := get_tree().current_scene
	get_tree().current_scene = root
	var boss := spawner.boss_instance
	var health: Health = boss.get_node("Health")
	health.die(DamageContext.new())
	await get_tree().process_frame
	get_tree().current_scene = previous
	assert_int(marks.get_child_count()).is_equal(1)


## The drawn decal is the same fraction of the enemy's art width for every enemy
## and every sheet, so bigger enemies leave proportionally bigger stains.
func test_size_follows_enemy_width() -> void:
	for tint in [DeathMark.Tint.NONE, DeathMark.Tint.PURPLE]:
		for i in RUNS:
			var mark := _mark(tint, 100.0)
			var drawn := mark.scale.x * float(_decal_of(mark).content_px)
			assert_float(drawn).is_between(
				100.0 * DeathMark.WIDTH_RATIO * (1.0 - DeathMark.SIZE_JITTER),
				100.0 * DeathMark.WIDTH_RATIO * (1.0 + DeathMark.SIZE_JITTER))
	assert_float(_mark(DeathMark.Tint.NONE, 200.0).scale.x) \
		.is_greater(_mark(DeathMark.Tint.NONE, 50.0).scale.x)
