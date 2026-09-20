extends Node2D
class_name Arena
## Simple rectangular combat arena with Brotato-style tiled ground.
##
## Centered on the Arena node's position (place at 0,0 so Rect is symmetric).
## Ground replicates Brotato 3.6 `MyTileMap`: a TileMapLayer filled with
## weighted-random tiles from a 3x4 atlas (`tiles_1.png`, copied from
## Brotato 3.6 `resources/tiles/`). The plain tile at atlas coords (2, 3)
## has weight 50 while every decorated tile (rocks, grass tufts, pebbles)
## has weight 1, so most cells are plain ground with occasional decoration
## scattered around — exactly like Brotato.
## - Walls are a StaticBody2D with 4 thick colliders keeping physics bodies inside.
## - Map edge uses Brotato's `tiles_outline.png` as a tinted NinePatchRect frame
##   extending one tile past the ground, with a jagged transparent rim so the
##   ground doesn't end in a straight line.

const ATLAS_COLS: int = 3
const ATLAS_ROWS: int = 4
## Atlas coords of the plain, decoration-free tile (bottom-right, like Brotato).
const PLAIN_TILE := Vector2i(2, 3)
## How far the outline frame extends past the ground on each side (one tile,
## matching Brotato's Outline offset and 64px nine-patch margins).
const OUTLINE_MARGIN: float = 64.0
## Physics layer the wall colliders live on (free bit: bodies use 1+2, areas
## use 1+2+3). Character/Enemy bodies include WALL_LAYER_BIT in their
## collision_mask so they stay inside; Area2Ds (projectiles, hitboxes,
## explosions) don't scan this layer, so they fly over the walls freely.
const WALL_PHYSICS_LAYER: int = 4
const WALL_LAYER_BIT: int = 1 << (WALL_PHYSICS_LAYER - 1)

@export var arena_size: Vector2 = Vector2(2048, 1536):
    set(value):
        arena_size = value
        _rebuild()

## Tile atlas texture. Must be a ATLAS_COLS x ATLAS_ROWS grid of tile_size px tiles.
@export var ground_texture: Texture2D = preload("res://src/Assets/tiles/tiles_1.png"):
    set(value):
        ground_texture = value
        _rebuild()

@export var tile_size: int = 64:
    set(value):
        tile_size = maxi(8, value)
        _rebuild()

## Weight of the plain tile in the random pick (Brotato uses 50, others use 1).
@export var plain_tile_weight: int = 50:
    set(value):
        plain_tile_weight = maxi(1, value)
        _rebuild()

## 0 = new random ground layout every run. Non-zero = deterministic (for tests).
@export var ground_seed: int = 0:
    set(value):
        ground_seed = value
        _rebuild()

@export var wall_color: Color = Color(0.470588, 0.403922, 0.345098, 1):
    set(value):
        wall_color = value
        _update_outline_color()

@export var wall_thickness: float = 64.0:
    set(value):
        wall_thickness = maxf(8.0, value)
        _rebuild()

## How far past the ground edge the wall inner faces sit. Bodies stop with
## their center one body-radius from the inner face, so a small outset lets
## the character/enemies press right onto the visible edge instead of
## stopping a full body-radius inside it. Clamped to >= 0 (walls must never
## move inward past the ground edge).
@export var wall_outset: float = 40.0:
    set(value):
        wall_outset = maxf(0.0, value)
        _rebuild()

## Outline frame texture (white frame with jagged transparent rim, tinted by
## wall_color — copied from Brotato 3.6 `resources/tiles/tiles_outline.png`).
@export var outline_texture: Texture2D = preload("res://src/Assets/tiles/tiles_outline.png"):
    set(value):
        outline_texture = value
        _rebuild()

@onready var walls: StaticBody2D = $Walls
@onready var ground: TileMapLayer = $Ground
@onready var outline: NinePatchRect = $Outline

var _tile_source_id: int = 0


func _ready() -> void:
    add_to_group("arena")
    _rebuild()


func _rebuild() -> void:
    if not is_node_ready():
        return
    _build_tileset()
    _build_walls()
    _fill_ground()
    _update_outline()


## Tint-only update: changing the outline color must NOT reshuffle the ground
## (which only happens in _rebuild, driven by a fresh random seed).
func _update_outline_color() -> void:
    if not is_node_ready() or outline == null:
        return
    outline.modulate = wall_color


func get_arena_rect() -> Rect2:
    var top_left: Vector2 = -arena_size * 0.5
    return Rect2(top_left, arena_size)


func is_inside(pos: Vector2, margin: float = 0.0) -> bool:
    return get_arena_rect().grow(-margin).has_point(to_local(pos))


func clamp_to_arena(pos: Vector2, margin: float = 0.0) -> Vector2:
    var rect: Rect2 = get_arena_rect().grow(-margin)
    var local: Vector2 = to_local(pos)
    local.x = clampf(local.x, rect.position.x, rect.position.x + rect.size.x)
    local.y = clampf(local.y, rect.position.y, rect.position.y + rect.size.y)
    return to_global(local)


func get_random_point_inside(margin: float = 64.0) -> Vector2:
    var rect: Rect2 = get_arena_rect().grow(-margin)
    var local := Vector2(
        randf_range(rect.position.x, rect.position.x + rect.size.x),
        randf_range(rect.position.y, rect.position.y + rect.size.y)
    )
    return to_global(local)


## Number of ground cells along each axis for the current arena_size.
func get_ground_grid_size() -> Vector2i:
    return Vector2i(roundi(arena_size.x / float(tile_size)), roundi(arena_size.y / float(tile_size)))


## Atlas coords of the tile placed at the given cell (for tests/debugging).
func get_cell_tile(cell: Vector2i) -> Vector2i:
    return ground.get_cell_atlas_coords(cell)


func get_ground_cells() -> Array[Vector2i]:
    return ground.get_used_cells()


func _build_tileset() -> void:
    if ground == null or ground_texture == null:
        return
    var atlas := TileSetAtlasSource.new()
    atlas.texture = ground_texture
    atlas.texture_region_size = Vector2i(tile_size, tile_size)
    for x in range(ATLAS_COLS):
        for y in range(ATLAS_ROWS):
            atlas.create_tile(Vector2i(x, y))
    var tileset := TileSet.new()
    tileset.tile_shape = TileSet.TILE_SHAPE_SQUARE
    tileset.tile_size = Vector2i(tile_size, tile_size)
    _tile_source_id = tileset.add_source(atlas)
    ground.tile_set = tileset


func _fill_ground() -> void:
    if ground == null:
        return
    ground.clear()
    var rng := RandomNumberGenerator.new()
    if ground_seed == 0:
        rng.randomize()
    else:
        rng.seed = ground_seed
    var bag := _build_tile_bag()
    var grid := get_ground_grid_size()
    var half_x := int(grid.x / 2.0)
    var half_y := int(grid.y / 2.0)
    for x in range(-half_x, grid.x - half_x):
        for y in range(-half_y, grid.y - half_y):
            ground.set_cell(Vector2i(x, y), _tile_source_id, bag[rng.randi_range(0, bag.size() - 1)])


## Weighted tile pool: every atlas tile once, plain tile plain_tile_weight times
## (mirrors Brotato's autotile priority_map = [Vector3(2, 3, 50)]).
func _build_tile_bag() -> Array[Vector2i]:
    var bag: Array[Vector2i] = []
    for x in range(ATLAS_COLS):
        for y in range(ATLAS_ROWS):
            var tile := Vector2i(x, y)
            if tile == PLAIN_TILE:
                continue
            bag.append(tile)
    for i in range(plain_tile_weight):
        bag.append(PLAIN_TILE)
    return bag


func _build_walls() -> void:
    if walls == null:
        return
    walls.collision_layer = WALL_LAYER_BIT
    walls.collision_mask = 0
    for child in walls.get_children():
        child.queue_free()
    # Inner faces sit wall_outset past the ground edge so bodies can press
    # onto the visible edge (they stop one body-radius from the face).
    var half: Vector2 = arena_size * 0.5 + Vector2(wall_outset, wall_outset)
    var depth: float = wall_thickness
    var corner: float = (depth + wall_outset) * 2.0
    # Left / right walls span full height + corners so there are no gaps.
    _add_wall(Vector2(-half.x - depth * 0.5, 0), Vector2(depth, arena_size.y + corner))
    _add_wall(Vector2(half.x + depth * 0.5, 0), Vector2(depth, arena_size.y + corner))
    _add_wall(Vector2(0, -half.y - depth * 0.5), Vector2(arena_size.x + corner, depth))
    _add_wall(Vector2(0, half.y + depth * 0.5), Vector2(arena_size.x + corner, depth))


func _add_wall(center: Vector2, size: Vector2) -> void:
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = size
    shape.shape = rect
    shape.position = center
    walls.add_child(shape)


## Frames the ground with the outline texture, one tile past the edge on each
## side (mirrors Brotato's Outline NinePatchRect: 64px patch margins, tiled
## edges, tinted with the background's outline color, drawn behind the tiles).
func _update_outline() -> void:
    if outline == null:
        return
    outline.texture = outline_texture
    outline.patch_margin_left = int(OUTLINE_MARGIN)
    outline.patch_margin_right = int(OUTLINE_MARGIN)
    outline.patch_margin_top = int(OUTLINE_MARGIN)
    outline.patch_margin_bottom = int(OUTLINE_MARGIN)
    outline.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
    outline.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
    outline.position = -arena_size * 0.5 - Vector2(OUTLINE_MARGIN, OUTLINE_MARGIN)
    outline.size = arena_size + Vector2(OUTLINE_MARGIN, OUTLINE_MARGIN) * 2.0
    outline.modulate = wall_color
