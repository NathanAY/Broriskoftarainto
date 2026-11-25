## Margin Call: a gold ring appears at the arena's edge and ticks during the
## telegraph, then closes in on the boss to `min_radius` over `close_time`,
## holds for `hold_time` and opens back out over `open_time`. Anything outside
## the ring takes `damage` every `hit_interval`. The boss stands still in the
## middle of it, so the fight is forced close.
## Counterplay: stay near the boss. Rough on kiting builds, kind to melee.
extends BossAttack

## The ring. Read by the tests.
var ring: GroundMarker = null

var _start_radius: float = 0.0
var _since_hit: float = 0.0


func _on_telegraph() -> void:
    _start_radius = _edge_radius()
    ring = GroundMarker.new()
    ring.radius = _start_radius
    ring.outline_width = float(cfg().get("ring_width", 24.0))
    ring.outline_color = Color(1.0, 0.82, 0.25, 0.9)
    BossBullets.world(boss).add_child(ring)
    ring.global_position = boss.global_position


## The ring blinks while it warns.
func _telegraph_tick(_delta: float) -> void:
    ring.visible = fmod(_time, 0.3) < 0.2


func _on_active() -> void:
    ring.visible = true
    _since_hit = float(cfg().get("hit_interval", 0.5))


func _active_tick(delta: float) -> bool:
    var close := float(cfg().get("close_time", 1.5))
    var hold := float(cfg().get("hold_time", 3.0))
    var open := float(cfg().get("open_time", 1.0))
    var min_radius := float(cfg().get("min_radius", 300.0))
    if _time < close:
        ring.radius = lerpf(_start_radius, min_radius, _time / close)
    elif _time < close + hold:
        ring.radius = min_radius
    else:
        ring.radius = lerpf(min_radius, _start_radius, clampf((_time - close - hold) / open, 0.0, 1.0))
    _since_hit += delta
    if _since_hit >= float(cfg().get("hit_interval", 0.5)):
        _since_hit = 0.0
        for node in BossBullets.victims(boss):
            if node.global_position.distance_to(ring.global_position) > ring.radius:
                BossBullets.hurt(boss, node, _damage("damage", 2.0), "margin_call")
    return _time >= close + hold + open


func _on_active_end() -> void:
    if ring != null and is_instance_valid(ring):
        ring.queue_free()
    ring = null


## Far enough that the ring starts outside every corner of the arena, so
## nothing is caught before it moves. `start_radius` without an arena.
func _edge_radius() -> float:
    var arena := boss.get_tree().get_first_node_in_group("arena") as Arena
    if arena == null:
        return float(cfg().get("start_radius", 1400.0))
    var rect := arena.get_arena_rect()
    var farthest := 0.0
    for corner in [rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y)]:
        farthest = maxf(farthest, arena.to_global(corner).distance_to(boss.global_position))
    return farthest
