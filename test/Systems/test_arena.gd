class_name ArenaTest
extends GdUnitTestSuite


func test_default_arena_rect_is_centered_medium_big() -> void:
	var arena: Arena = auto_free(load("res://src/Systems/Arena.tscn").instantiate())
	add_child(arena)
	var rect: Rect2 = arena.get_arena_rect()
	assert_that(rect.size).is_equal(Vector2(2048, 1536))
	assert_that(rect.position).is_equal(Vector2(-1024, -768))
	assert_bool(rect.has_point(Vector2.ZERO)).is_true()


func test_random_point_inside_stays_in_arena() -> void:
	var arena: Arena = auto_free(load("res://src/Systems/Arena.tscn").instantiate())
	add_child(arena)
	for i in range(20):
		var p: Vector2 = arena.get_random_point_inside(64.0)
		assert_bool(arena.get_arena_rect().has_point(arena.to_local(p))).is_true()


func test_clamp_to_arena_keeps_inside() -> void:
	var arena: Arena = auto_free(load("res://src/Systems/Arena.tscn").instantiate())
	add_child(arena)
	var clamped: Vector2 = arena.clamp_to_arena(Vector2(99999, -99999))
	# Rect2.has_point() excludes the right/bottom edge, so check with a
	# 1px grown rect plus explicit bounds.
	var rect: Rect2 = arena.get_arena_rect()
	assert_bool(rect.grow(1.0).has_point(arena.to_local(clamped))).is_true()
	assert_bool(clamped.x <= rect.position.x + rect.size.x).is_true()
	assert_bool(clamped.y >= rect.position.y).is_true()


func test_walls_have_four_colliders() -> void:
	var arena: Arena = auto_free(load("res://src/Systems/Arena.tscn").instantiate())
	add_child(arena)
	var walls: StaticBody2D = arena.get_node("Walls")
	assert_int(walls.get_child_count()).is_equal(4)


func test_custom_size_and_colors_apply() -> void:
	var arena: Arena = auto_free(load("res://src/Systems/Arena.tscn").instantiate())
	arena.arena_size = Vector2(640, 320)
	arena.wall_color = Color.RED
	add_child(arena)
	assert_that(arena.get_arena_rect().size).is_equal(Vector2(640, 320))
	assert_that(arena.wall_color).is_equal(Color.RED)
	assert_that(arena.get_ground_grid_size()).is_equal(Vector2i(10, 5))
	assert_int(arena.get_node("Walls").get_child_count()).is_equal(4)


func test_game_with_ground_scene_contains_arena() -> void:
	var packed: PackedScene = load("res://src/Scenes/Game.tscn")
	assert_object(packed).is_not_null()
	var state: SceneState = packed.get_state()
	var found := false
	for i in range(state.get_node_count()):
		if state.get_node_name(i) == &"Arena":
			found = true
			break
	assert_bool(found).is_true()


func test_ground_fills_expected_cell_count() -> void:
	var arena: Arena = auto_free(load("res://src/Systems/Arena.tscn").instantiate())
	arena.ground_seed = 12345
	add_child(arena)
	# Default 2048x1536 with 64px tiles = 32x24 cells, centered on origin.
	assert_that(arena.get_ground_grid_size()).is_equal(Vector2i(32, 24))
	var cells: Array[Vector2i] = arena.get_ground_cells()
	assert_int(cells.size()).is_equal(32 * 24)
	assert_bool(cells.has(Vector2i(-16, -12))).is_true()
	assert_bool(cells.has(Vector2i(15, 11))).is_true()


func test_ground_tiles_come_from_atlas() -> void:
	var arena: Arena = auto_free(load("res://src/Systems/Arena.tscn").instantiate())
	arena.ground_seed = 12345
	add_child(arena)
	for cell in arena.get_ground_cells():
		var tile: Vector2i = arena.get_cell_tile(cell)
		assert_bool(tile.x >= 0 and tile.x < Arena.ATLAS_COLS).is_true()
		assert_bool(tile.y >= 0 and tile.y < Arena.ATLAS_ROWS).is_true()


func test_plain_tile_is_majority() -> void:
	var arena: Arena = auto_free(load("res://src/Systems/Arena.tscn").instantiate())
	arena.ground_seed = 12345
	add_child(arena)
	var cells: Array[Vector2i] = arena.get_ground_cells()
	var plain_count := 0
	for cell in cells:
		if arena.get_cell_tile(cell) == Arena.PLAIN_TILE:
			plain_count += 1
	# Plain tile has weight 50 out of 61 (~82%), so it must dominate.
	assert_bool(plain_count * 2 > cells.size()).is_true()


func test_ground_seed_is_deterministic() -> void:
	var first: Arena = auto_free(load("res://src/Systems/Arena.tscn").instantiate())
	first.ground_seed = 777
	add_child(first)
	var second: Arena = auto_free(load("res://src/Systems/Arena.tscn").instantiate())
	second.ground_seed = 777
	add_child(second)
	var first_cells: Array[Vector2i] = first.get_ground_cells()
	assert_int(first_cells.size()).is_equal(second.get_ground_cells().size())
	for cell in first_cells:
		assert_that(first.get_cell_tile(cell)).is_equal(second.get_cell_tile(cell))


func test_outline_frames_ground() -> void:
	var arena: Arena = auto_free(load("res://src/Systems/Arena.tscn").instantiate())
	add_child(arena)
	var outline: NinePatchRect = arena.get_node("Outline")
	assert_object(outline.texture).is_not_null()
	# Frame extends one tile (64px) past the ground on each side, like Brotato.
	assert_that(outline.position).is_equal(Vector2(-1024 - 64, -768 - 64))
	assert_that(outline.size).is_equal(Vector2(2048 + 128, 1536 + 128))
	assert_that(outline.modulate).is_equal(arena.wall_color)
	assert_int(outline.patch_margin_left).is_equal(64)
	assert_int(outline.patch_margin_top).is_equal(64)
	assert_that(outline.axis_stretch_horizontal).is_equal(NinePatchRect.AXIS_STRETCH_MODE_TILE)


func test_outline_color_change_keeps_ground_layout() -> void:
	var arena: Arena = auto_free(load("res://src/Systems/Arena.tscn").instantiate())
	arena.ground_seed = 4242
	add_child(arena)
	var before: Dictionary = {}
	for cell in arena.get_ground_cells():
		before[cell] = arena.get_cell_tile(cell)
	arena.wall_color = Color.BLUE
	assert_that(arena.get_node("Outline").modulate).is_equal(Color.BLUE)
	for cell in arena.get_ground_cells():
		assert_that(arena.get_cell_tile(cell)).is_equal(before[cell])


## Inner face of a wall collider: position +/- half size toward the arena.
func _inner_face(wall: CollisionShape2D, axis: String) -> float:
	var half: float = (wall.shape as RectangleShape2D).size.x * 0.5 if axis == "x" else (wall.shape as RectangleShape2D).size.y * 0.5
	var pos: float = wall.position.x if axis == "x" else wall.position.y
	return pos + half if pos < 0.0 else pos - half


func test_walls_default_outset_sits_faces_past_edge() -> void:
	var arena: Arena = auto_free(load("res://src/Systems/Arena.tscn").instantiate())
	add_child(arena)
	assert_float(arena.wall_outset).is_equal(40.0)
	var walls: Node = arena.get_node("Walls")
	# Children order: left, right, top, bottom.
	assert_float(_inner_face(walls.get_child(0), "x")).is_equal(-1024.0 - 40.0)
	assert_float(_inner_face(walls.get_child(1), "x")).is_equal(1024.0 + 40.0)
	assert_float(_inner_face(walls.get_child(2), "y")).is_equal(-768.0 - 40.0)
	assert_float(_inner_face(walls.get_child(3), "y")).is_equal(768.0 + 40.0)


func test_custom_wall_outset_applies() -> void:
	var arena: Arena = auto_free(load("res://src/Systems/Arena.tscn").instantiate())
	arena.wall_outset = 0.0
	add_child(arena)
	var walls: Node = arena.get_node("Walls")
	assert_float(_inner_face(walls.get_child(0), "x")).is_equal(-1024.0)
	assert_float(_inner_face(walls.get_child(1), "x")).is_equal(1024.0)
	arena.wall_outset = 32.0
	# Rebuild queue_frees old colliders; wait a frame so child list is fresh.
	await get_tree().process_frame
	assert_float(_inner_face(walls.get_child(0), "x")).is_equal(-1024.0 - 32.0)
	assert_float(_inner_face(walls.get_child(3), "y")).is_equal(768.0 + 32.0)
	assert_int(walls.get_child_count()).is_equal(4)


func test_wall_outset_never_goes_negative() -> void:
	var arena: Arena = auto_free(load("res://src/Systems/Arena.tscn").instantiate())
	arena.wall_outset = -50.0
	add_child(arena)
	assert_float(arena.wall_outset).is_equal(0.0)
	var walls: Node = arena.get_node("Walls")
	assert_float(_inner_face(walls.get_child(0), "x")).is_equal(-1024.0)

func test_walls_use_dedicated_physics_layer() -> void:
	var arena: Arena = auto_free(load("res://src/Systems/Arena.tscn").instantiate())
	add_child(arena)
	var walls: StaticBody2D = arena.get_node("Walls")
	assert_int(Arena.WALL_LAYER_BIT).is_equal(8)
	assert_int(walls.collision_layer).is_equal(Arena.WALL_LAYER_BIT)
	assert_int(walls.collision_mask).is_equal(0)


func test_character_body_collides_with_walls() -> void:
	var character: CharacterBody2D = auto_free(load("res://src/Systems/Character.tscn").instantiate())
	add_child(character)
	assert_int(character.collision_layer).is_equal(1)
	assert_bool((character.collision_mask & Arena.WALL_LAYER_BIT) != 0).is_true()
	# Hitbox is for combat detection, not walls — walls must not trigger it.
	var hitbox: Area2D = character.get_node("Hitbox")
	assert_bool((hitbox.collision_mask & Arena.WALL_LAYER_BIT) == 0).is_true()


func test_enemy_body_collides_with_walls() -> void:
	var enemy: CharacterBody2D = auto_free(load("res://src/Systems/Enemy.tscn").instantiate())
	add_child(enemy)
	assert_int(enemy.collision_layer).is_equal(2)
	# Enemies only collide with walls; crowding uses soft separation so packed
	# groups no longer hard-push/slide each other sideways.
	assert_bool((enemy.collision_mask & 2) == 0).is_true()
	assert_bool((enemy.collision_mask & Arena.WALL_LAYER_BIT) != 0).is_true()
	var hitbox: Area2D = enemy.get_node("Hitbox")
	assert_bool((hitbox.collision_mask & Arena.WALL_LAYER_BIT) == 0).is_true()


func test_projectiles_and_effects_fly_over_walls() -> void:
	var scenes := [
		"res://src/Systems/weapon/Projectile.tscn",
		"res://src/Systems/weapon/RocketProjectile.tscn",
		"res://src/Systems/weapon/LightningProjectile.tscn",
		"res://src/Scenes/OrbitingOrb.tscn",
		"res://src/Scenes/Explosion.tscn",
	]
	for path in scenes:
		var packed: PackedScene = load(path)
		assert_object(packed).is_not_null()
		if packed == null:
			continue
		var node: Node = auto_free(packed.instantiate())
		assert_object(node).is_not_null()
		if node == null:
			continue
		# The Area2D may be the root (projectiles) or a child (OrbitingOrb).
		var area := _find_area(node)
		assert_object(area).is_not_null()
		if area == null:
			continue
		assert_bool((area.collision_mask & Arena.WALL_LAYER_BIT) == 0).is_true()


## First Area2D in the subtree (the node itself or a descendant).
func _find_area(node: Node) -> Area2D:
	if node is Area2D:
		return node
	for child in node.get_children():
		var found := _find_area(child)
		if found != null:
			return found
	return null

