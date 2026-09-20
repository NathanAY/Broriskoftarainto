class_name SpawnerArenaGdUnit4Test
extends GdUnitTestSuite


## Minimal runtime tree: TestRoot/Arena?, TestRoot/Nodes/Enemies,
## TestRoot/StageManager/<spawner>, TestRoot/Character.
## Default character position is far outside the arena so ring spawns must be
## clamped; tests with staggered spawns (awaits let enemies walk) place the
## character inside near the edge instead, so chase drift goes inward.
func _build_tree(with_arena: bool, spawner_scene: String, character_pos: Vector2 = Vector2(10000, 0)) -> Dictionary:
	var root: Node = auto_free(Node.new())
	root.name = "TestRoot"
	add_child(root)
	var arena: Arena = null
	if with_arena:
		arena = auto_free(load("res://src/Systems/Arena.tscn").instantiate())
		root.add_child(arena)
	var nodes := Node.new()
	nodes.name = "Nodes"
	root.add_child(nodes)
	var enemies := Node.new()
	enemies.name = "Enemies"
	nodes.add_child(enemies)
	var stage := Node.new()
	stage.name = "StageManager"
	root.add_child(stage)
	var character: CharacterBody2D = auto_free(load("res://src/Systems/Character.tscn").instantiate())
	root.add_child(character)
	character.global_position = character_pos
	var spawner: Node = auto_free(load(spawner_scene).instantiate())
	spawner.set("character", character)
	stage.add_child(spawner)
	return {"root": root, "arena": arena, "enemies": enemies, "character": character, "spawner": spawner}


func _assert_inside_arena(arena: Arena, pos: Vector2) -> void:
	# Clamp margin is 64; check with 63 so exact-edge points still count.
	var rect: Rect2 = arena.get_arena_rect()
	assert_bool(rect.grow(-63.0).has_point(arena.to_local(pos))).is_true()


func test_spawner_finds_arena_automatically() -> void:
	var ctx: Dictionary = _build_tree(true, "res://src/Systems/EnemySpawner.tscn")
	assert_object(ctx["spawner"].get("arena")).is_not_null()


func test_single_spawn_clamped_inside_arena() -> void:
	var ctx: Dictionary = _build_tree(true, "res://src/Systems/EnemySpawner.tscn")
	var spawner: EnemySpawner = ctx["spawner"]
	spawner.use_group_spawning = false
	spawner.spawn_enemy()
	var enemies: Node = ctx["enemies"]
	assert_int(enemies.get_child_count()).is_equal(1)
	_assert_inside_arena(ctx["arena"], (enemies.get_child(0) as Node2D).global_position)


func test_group_spawn_stays_inside_arena() -> void:
	var ctx: Dictionary = _build_tree(true, "res://src/Systems/EnemySpawner.tscn", Vector2(900, 0))
	var spawner: EnemySpawner = ctx["spawner"]
	# Deterministic clamp check (group flow itself is random-angle based).
	_assert_inside_arena(ctx["arena"], spawner.clamp_spawn_position(Vector2(5000, 5000)))
	_assert_inside_arena(ctx["arena"], spawner.clamp_spawn_position(Vector2(-5000, -5000)))
	spawner.group_spawn_interval = 0.01
	await spawner.spawn_enemy_group()
	var enemies: Node = ctx["enemies"]
	assert_bool(enemies.get_child_count() > 0).is_true()
	for enemy in enemies.get_children():
		_assert_inside_arena(ctx["arena"], (enemy as Node2D).global_position)


func test_boss_spawn_clamped_inside_arena() -> void:
	var ctx: Dictionary = _build_tree(true, "res://src/Systems/BossSpawner.tscn")
	var spawner: BossSpawner = ctx["spawner"]
	assert_object(spawner.arena).is_not_null()
	spawner.spawn_boss()
	assert_object(spawner.boss_instance).is_not_null()
	_assert_inside_arena(ctx["arena"], spawner.boss_instance.global_position)


func test_spawn_unclamped_without_arena() -> void:
	var ctx: Dictionary = _build_tree(false, "res://src/Systems/EnemySpawner.tscn")
	var spawner: EnemySpawner = ctx["spawner"]
	assert_object(spawner.arena).is_null()
	spawner.use_group_spawning = false
	spawner.spawn_enemy()
	var enemies: Node = ctx["enemies"]
	assert_int(enemies.get_child_count()).is_equal(1)
	var enemy_pos: Vector2 = (enemies.get_child(0) as Node2D).global_position
	var character_pos: Vector2 = (ctx["character"] as Node2D).global_position
	# Unclamped ring position: exactly 500 from the character (no arena to pull it in).
	assert_float((enemy_pos - character_pos).length()).is_equal_approx(500.0, 1.0)
