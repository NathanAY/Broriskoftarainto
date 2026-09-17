# TextureBurst.gd
# 2D port of Wild West `enemy_texture_burst` (Node3D + GPUParticles3D + spatial shaders).
# Same technique: slice the death-frame texture into an 4x4 grid (32 pieces) and
# burst them along `direction` with `strength` (clamped 0.8-2.2 like the original).
# Differences are only 2D adaptations: Sprite2D instead of AnimatedSprite3D,
# Vector2 instead of Vector3, Node2D shards instead of GPUParticles3D, top-down
# friction instead of floor_y bounce.
# Reusable for any Node2D owner with a Sprite2D (enemies now, other objects later).
extends Node2D
class_name TextureBurst

const GRID_SIZE := 4
const PIECE_COUNT := 32

@export var lifetime := 1.0
@export var outward_speed := 220.0
@export var impact_push_min := 90.0
@export var impact_push_max := 260.0
@export var damping := 2.4
@export var spin_max := 10.0

var _shards: Array[Dictionary] = []
var _age := 0.0
var _configured := false


func configure(sprite: Sprite2D, direction: Vector2, strength: float) -> void:
    if sprite == null or sprite.texture == null:
        return
    var root_atlas: Texture2D = sprite.texture
    var frame_origin := Vector2.ZERO
    var frame_size := root_atlas.get_size()
    # Unwrap AtlasTexture so slices reference the real atlas (mirrors WW logic).
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
    if frame_size.x <= 0.0 or frame_size.y <= 0.0:
        return
    var slice := frame_size / float(GRID_SIZE)
    if slice.x < 1.0 or slice.y < 1.0:
        return
    var dir := direction
    if dir.length_squared() < 0.0001:
        dir = Vector2.RIGHT
    else:
        dir = dir.normalized()
    var power: float = clampf(strength, 0.8, 2.2)
    var flip_h: bool = sprite.flip_h
    var base_modulate: Color = sprite.modulate
    var shard_scale: Vector2 = sprite.scale if sprite.scale.length_squared() > 0.0 else Vector2.ONE
    var sprite_offset: Vector2 = sprite.offset
    for index in range(PIECE_COUNT):
        var tx: int = index % GRID_SIZE
        var ty: int = int(float(index) / float(GRID_SIZE))
        var center := Vector2((float(tx) + 0.5) / float(GRID_SIZE), (float(ty) + 0.5) / float(GRID_SIZE))
        var slice_rect := Rect2(frame_origin + Vector2(tx, ty) * slice, slice)
        var atlas_slice := AtlasTexture.new()
        atlas_slice.atlas = root_atlas
        atlas_slice.region = slice_rect
        var piece := Sprite2D.new()
        piece.texture = atlas_slice
        piece.centered = true
        piece.flip_h = flip_h
        piece.flip_v = sprite.flip_v
        piece.modulate = base_modulate
        piece.scale = shard_scale
        # Local offset from sprite center (mirrors WW canvas_offset math, 2D top-down).
        var local := (Vector2(center.x - 0.5, center.y - 0.5)) * frame_size + sprite_offset
        if flip_h:
            local.x = -local.x
        piece.position = local
        add_child(piece)
        # Outward velocity from tile center + impact push + per-piece jitter.
        var outward := Vector2(center.x - 0.5, center.y - 0.5)
        if outward.length_squared() < 0.0001:
            outward = Vector2.RIGHT
        else:
            outward = outward.normalized()
        var jitter: float = randf_range(0.6, 1.4)
        var push: float = randf_range(impact_push_min, impact_push_max) * power
        var vel: Vector2 = outward * outward_speed * jitter + dir * push
        vel += Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
        _shards.append({
            "node": piece,
            "vel": vel,
            "ang_vel": randf_range(-spin_max, spin_max),
        })
    _configured = true
    _age = 0.0


func _process(delta: float) -> void:
    if not _configured:
        return
    _age += delta
    var fade: float = 1.0 - smoothstep(0.55, lifetime, _age)
    var damp_factor: float = exp(-damping * delta)
    for shard in _shards:
        var node: Sprite2D = shard["node"]
        if not is_instance_valid(node):
            continue
        var vel: Vector2 = shard["vel"]
        vel *= damp_factor
        shard["vel"] = vel
        node.position += vel * delta
        node.rotation += float(shard["ang_vel"]) * delta
        var c: Color = node.modulate
        c.a = fade
        node.modulate = c
    if _age >= lifetime:
        queue_free()


func get_piece_count() -> int:
    return _shards.size()
