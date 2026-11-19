# TextureBurst.gd
# 2D port of Wild West `enemy_texture_burst` (Node3D + GPUParticles3D + spatial shaders).
# The death frame is broken like a cracked pane of glass: cracks radiate from an
# impact point and are joined by ragged rings, so the pieces are a spider web of
# small splinters near the middle and big irregular slabs towards the edge. Each
# piece is a textured Polygon2D and bursts along `direction` with `strength`
# (clamped 0.8-2.2 like the original).
# 2D adaptations: Sprite2D instead of AnimatedSprite3D, Vector2 instead of
# Vector3, Node2D shards instead of GPUParticles3D, top-down friction instead of
# floor_y bounce.
# Reusable for any Node2D owner with a Sprite2D (enemies now, other objects later).
extends Node2D
class_name TextureBurst

## Radial cracks, picked per burst.
const MIN_CRACKS := 9
const MAX_CRACKS := 13
## Ring radii as a fraction of the frame's half-diagonal. The last ring is far
## outside the frame, so clipping to the frame (not the web) sets the outline.
const RING_FRACTIONS := [0.16, 0.38, 0.68, 1.8]
## How far a ring vertex may wander in or out, as a fraction of its radius.
const RING_JITTER := 0.22
## How far the impact point may sit from the frame centre, as a fraction of the frame size.
const IMPACT_JITTER := 0.15

@export var lifetime := 1.2
@export var outward_speed := 140.0
@export var impact_push_min := 30.0
@export var impact_push_max := 90.0
@export var damping := 1.6
@export var spin_max := 5.0

var _shards: Array[Dictionary] = []
var _age := 0.0
var _configured := false
var _speed_multiplier := 1.0


func configure(sprite: Sprite2D, direction: Vector2, strength: float, speed_multiplier := 1.0) -> void:
    if sprite == null or sprite.texture == null:
        return
    _speed_multiplier = maxf(speed_multiplier, 0.0)
    var root_atlas: Texture2D = sprite.texture
    var frame_origin := Vector2.ZERO
    var frame_size := root_atlas.get_size()
    # Unwrap AtlasTexture so UVs reference the real atlas (mirrors WW logic).
    if root_atlas is AtlasTexture:
        var atlas_tex := root_atlas as AtlasTexture
        if atlas_tex.atlas != null:
            frame_origin = atlas_tex.region.position
            frame_size = atlas_tex.region.size
            root_atlas = atlas_tex.atlas
    # Sprite2D hframes/vframes slicing (WW used AnimatedSprite3D frames).
    var hframes: int = maxi(sprite.hframes, 1)
    var vframes: int = maxi(sprite.vframes, 1)
    if hframes > 1 or vframes > 1:
        var cell := Vector2(frame_size.x / hframes, frame_size.y / vframes)
        var fx: int = sprite.frame % hframes
        var fy: int = int(float(sprite.frame) / float(hframes))
        frame_origin += Vector2(fx, fy) * cell
        frame_size = cell
    # Sprite2D region_rect slicing.
    if sprite.region_enabled:
        # region_rect is already in texture space; intersect with frame above.
        frame_origin = sprite.region_rect.position
        frame_size = sprite.region_rect.size
    if frame_size.x < 4.0 or frame_size.y < 4.0:
        return
    var dir := direction
    if dir.length_squared() < 0.0001:
        dir = Vector2.RIGHT
    else:
        dir = dir.normalized()
    var power: float = clampf(strength, 0.8, 2.2)
    var flip_h: bool = sprite.flip_h
    var flip_v: bool = sprite.flip_v
    var tint: Color = sprite.modulate
    # The drawn scale, not just the sprite's own: the fit for source-size art
    # lives on the parent container, and a shard has to match the creature on
    # screen. `global_transform` folds both in.
    var shard_scale: Vector2 = sprite.global_transform.get_scale()
    if shard_scale.length_squared() <= 0.0:
        shard_scale = Vector2.ONE
    var sprite_offset: Vector2 = sprite.offset
    var half := frame_size * 0.5
    # Frame-space point (0..frame_size) -> where that pixel is drawn, relative to
    # the sprite's centre, in screen pixels. Flips mirror it like Sprite2D does.
    var to_local := func(point: Vector2) -> Vector2:
        var d: Vector2 = point - half
        if flip_h:
            d.x = -d.x
        if flip_v:
            d.y = -d.y
        return (d + sprite_offset) * shard_scale
    for cell_polygon in crack_pieces(frame_size):
        _add_shard(cell_polygon, root_atlas, frame_origin, to_local, tint, dir, power)
    _configured = true
    _age = 0.0


## The frame cut into a spider web: random radial cracks from an impact point,
## joined by ragged rings. Returns convex-ish polygons in frame pixels that tile
## the frame exactly (shared vertices, then clipped to the frame rectangle).
static func crack_pieces(frame_size: Vector2) -> Array[PackedVector2Array]:
    var impact := frame_size * 0.5 + Vector2(
        randf_range(-IMPACT_JITTER, IMPACT_JITTER) * frame_size.x,
        randf_range(-IMPACT_JITTER, IMPACT_JITTER) * frame_size.y)
    var reach := frame_size.length() * 0.5
    var cracks := randi_range(MIN_CRACKS, MAX_CRACKS)
    var step := TAU / float(cracks)
    var start := randf() * TAU
    # ring_points[k][i]: where crack i crosses ring k. Ring 0 is the impact point
    # itself, so the middle of the web is a fan rather than a hole.
    var ring_points: Array = []
    for ring in range(RING_FRACTIONS.size()):
        var points: Array[Vector2] = []
        for crack in range(cracks):
            var angle := start + (float(crack) + randf_range(-0.3, 0.3)) * step
            var radius: float = RING_FRACTIONS[ring] * reach \
                    * (1.0 + randf_range(-RING_JITTER, RING_JITTER))
            points.append(impact + Vector2.from_angle(angle) * radius)
        ring_points.append(points)
    var frame := PackedVector2Array([
        Vector2.ZERO, Vector2(frame_size.x, 0.0), frame_size, Vector2(0.0, frame_size.y)])
    var cells: Array[PackedVector2Array] = []
    for crack in range(cracks):
        var next := (crack + 1) % cracks
        cells.append(PackedVector2Array([impact, ring_points[0][crack], ring_points[0][next]]))
        for ring in range(RING_FRACTIONS.size() - 1):
            cells.append(PackedVector2Array([
                ring_points[ring][crack], ring_points[ring + 1][crack],
                ring_points[ring + 1][next], ring_points[ring][next]]))
    var pieces: Array[PackedVector2Array] = []
    for cell in cells:
        for clipped in Geometry2D.intersect_polygons(cell, frame):
            if clipped.size() >= 3 and _polygon_area(clipped) > 1.0:
                pieces.append(clipped)
    return pieces


static func _polygon_area(polygon: PackedVector2Array) -> float:
    var twice := 0.0
    for index in range(polygon.size()):
        twice += polygon[index].cross(polygon[(index + 1) % polygon.size()])
    return absf(twice) * 0.5


## One shard. The node sits at the polygon's centre so it spins about its own
## middle; vertices are relative to it and UVs are absolute pixels in the source
## texture, so no atlas slice is needed. Small splinters fly faster than slabs.
func _add_shard(corners: PackedVector2Array, texture: Texture2D, frame_origin: Vector2,
        to_local: Callable, tint: Color, dir: Vector2, power: float) -> void:
    var centroid := Vector2.ZERO
    for corner in corners:
        centroid += corner
    centroid /= float(corners.size())
    var centre_local: Vector2 = to_local.call(centroid)
    var points := PackedVector2Array()
    var uvs := PackedVector2Array()
    for corner in corners:
        points.append(to_local.call(corner) - centre_local)
        uvs.append(frame_origin + corner)
    var piece := Polygon2D.new()
    piece.texture = texture
    piece.polygon = points
    piece.uv = uvs
    piece.color = tint
    piece.position = centre_local
    add_child(piece)
    var outward := centre_local
    if outward.length_squared() < 0.0001:
        outward = Vector2.RIGHT
    outward = outward.normalized()
    var lightness: float = clampf(1.6 - sqrt(_polygon_area(corners)) / 40.0, 0.7, 1.6)
    var vel: Vector2 = outward * outward_speed * randf_range(0.6, 1.4) * lightness \
            + dir * randf_range(impact_push_min, impact_push_max) * power
    vel += Vector2(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0))
    vel *= _speed_multiplier
    _shards.append({
        "node": piece,
        "vel": vel,
        "ang_vel": randf_range(-spin_max, spin_max) * lightness,
    })


func _process(delta: float) -> void:
    if not _configured:
        return
    _age += delta
    var fade: float = 1.0 - smoothstep(0.55, lifetime, _age)
    # Braking grows with the overkill boost, so a one-shot on a 1-health enemy
    # still bursts violently but the pieces stop on screen: travel is
    # speed / damping, which would otherwise grow linearly with the boost and
    # throw every piece thousands of pixels away before it fades.
    var damp_factor: float = exp(-damping * sqrt(maxf(_speed_multiplier, 1.0)) * delta)
    for shard in _shards:
        var node: Polygon2D = shard["node"]
        if not is_instance_valid(node):
            continue
        var vel: Vector2 = shard["vel"]
        vel *= damp_factor
        shard["vel"] = vel
        node.position += vel * delta
        node.rotation += float(shard["ang_vel"]) * delta
        node.modulate.a = fade
    if _age >= lifetime:
        queue_free()


func get_piece_count() -> int:
    return _shards.size()


func get_speed_multiplier() -> float:
    return _speed_multiplier
