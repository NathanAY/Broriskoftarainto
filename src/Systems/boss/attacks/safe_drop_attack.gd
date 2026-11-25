## Safe Drop: lobs `count` safes. A shadow grows on the ground at each landing
## spot for `fall_time`, the safe drops into it, and it explodes. One safe
## always lands on the player's position; the rest land where the player is
## heading, scattered by up to `scatter` px.
## Counterplay: keep moving, stay out of the shadows.
extends BossAttack

const SAFE_TEXTURE := preload("res://src/Assets/boss/boss_safe.png")

## The landing markers of the drop in flight. Read by the tests.
var markers: Array[GroundMarker] = []


func _on_active() -> void:
    var radius := float(cfg().get("radius", 90.0))
    var fall := float(cfg().get("fall_time", 1.0))
    var lead := target.global_position
    if "velocity" in target:
        lead += target.velocity * fall
    for i in int(cfg().get("count", 5)):
        var spot := target.global_position
        if i > 0:
            var scatter := float(cfg().get("scatter", 160.0))
            spot = lead + Vector2.from_angle(_rng().randf() * TAU) * _rng().randf() * scatter
        _add_marker(BossBullets.clamp_to_arena(boss, spot, radius * 0.5), radius)


func _active_tick(_delta: float) -> bool:
    var fall := float(cfg().get("fall_time", 1.0))
    var progress := clampf(_time / fall, 0.0, 1.0)
    for marker in markers:
        marker.progress = progress
        var safe := marker.get_node("Safe") as Node2D
        safe.position.y = -float(cfg().get("drop_height", 400.0)) * (1.0 - progress)
    if _time < fall:
        return false
    var damage := _damage("damage", 4.0)
    for marker in markers:
        BossBullets.blast(boss, marker.global_position, marker.radius, damage)
    if not markers.is_empty():
        _impact(markers[0].global_position, "blast")
    return true


func _on_active_end() -> void:
    for marker in markers:
        if is_instance_valid(marker):
            marker.queue_free()
    markers.clear()


func _add_marker(at: Vector2, radius: float) -> void:
    var marker := GroundMarker.new()
    marker.radius = radius
    var safe := Sprite2D.new()
    safe.name = "Safe"
    safe.texture = SAFE_TEXTURE
    safe.scale = Vector2.ONE * (float(cfg().get("safe_size", 56.0)) / SAFE_TEXTURE.get_width())
    safe.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    safe.z_index = 2
    marker.add_child(safe)
    BossBullets.world(boss).add_child(marker)
    marker.global_position = at
    markers.append(marker)
