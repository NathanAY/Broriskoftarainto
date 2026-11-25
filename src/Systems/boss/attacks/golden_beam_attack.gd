## Golden Beam: a thin aim line shows where the beam starts, then a beam from
## the core sweeps `arc_deg` over `sweep_time`, in a random direction. Anything
## damageable (not an enemy) inside the beam takes `damage` at most once per
## `hit_interval`.
## Counterplay: move with the sweep, or get behind the boss.
extends BossAttack

## The beam's current direction. Read by the tests.
var direction: Vector2 = Vector2.RIGHT

var _start_angle: float = 0.0
var _sweep_sign: float = 1.0
var _line: Line2D = null
var _last_hit: Dictionary = {}


func _on_telegraph() -> void:
    _sweep_sign = 1.0 if _rng().randf() < 0.5 else -1.0
    _line = Line2D.new()
    _line.width = 3.0
    _line.default_color = Color(1.0, 0.85, 0.3, 0.6)
    # Behind the body, so the beam reads as coming out of the vault.
    _line.z_index = -1
    boss.add_child(_line)
    _telegraph_tick(0.0)


## The aim line tracks until the beam fires, offset to where the sweep starts.
func _telegraph_tick(_delta: float) -> void:
    _start_angle = _aim().angle() - _sweep_sign * deg_to_rad(float(cfg().get("arc_deg", 120.0))) * 0.5
    _set_direction(Vector2.from_angle(_start_angle))


func _on_active() -> void:
    _last_hit.clear()
    _line.width = float(cfg().get("width", 36.0))
    _line.default_color = Color(1.0, 0.82, 0.25, 0.85)
    var core := Line2D.new()
    core.name = "Core"
    core.width = _line.width * 0.35
    core.default_color = Color(1.0, 0.97, 0.8)
    _line.add_child(core)
    _set_direction(direction)


func _active_tick(_delta: float) -> bool:
    var sweep := float(cfg().get("sweep_time", 2.5))
    var t := clampf(_time / sweep, 0.0, 1.0)
    _set_direction(Vector2.from_angle(_start_angle + _sweep_sign * deg_to_rad(float(cfg().get("arc_deg", 120.0))) * t))
    _burn()
    return _time >= sweep


func _on_active_end() -> void:
    if _line != null and is_instance_valid(_line):
        _line.queue_free()
    _line = null


## Whether `point` is inside the beam right now.
func is_in_beam(point: Vector2) -> bool:
    var from := boss.global_position
    var to := from + direction * float(cfg().get("length", 900.0))
    var closest := Geometry2D.get_closest_point_to_segment(point, from, to)
    return closest.distance_to(point) <= float(cfg().get("width", 36.0)) * 0.5


func _burn() -> void:
    var interval := float(cfg().get("hit_interval", 0.4))
    for node in BossBullets.victims(boss):
        if not is_in_beam(node.global_position):
            continue
        var id := node.get_instance_id()
        if _last_hit.has(id) and _time - float(_last_hit[id]) < interval:
            continue
        _last_hit[id] = _time
        BossBullets.hurt(boss, node, _damage("damage", 2.0), "beam")


func _set_direction(dir: Vector2) -> void:
    direction = dir
    if _line != null:
        _line.points = PackedVector2Array([Vector2.ZERO, direction * float(cfg().get("length", 900.0))])
        var core := _line.get_node_or_null("Core") as Line2D
        if core != null:
            core.points = _line.points
