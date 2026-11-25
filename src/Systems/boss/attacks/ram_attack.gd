## Hostile Ram (and Double Ram): rears back behind a red line showing where it
## will go, then charges along the direction locked when the telegraph ends.
## With `charges` > 1 it pauses `between` seconds after each charge, the line
## re-aiming at the player, and charges again. A wall hit ends that charge
## early; a wall hit on the last charge adds `wall_stagger` to the recovery.
## Counterplay: step off the line; hit it in the back while it is staggered.
##
## The charge speed is a `Stats` modifier, not a raw velocity: `Enemy` clamps
## the velocity to the movement-speed stat (see `ChargeMovementBehaviour`).
extends BossAttack

var direction: Vector2 = Vector2.RIGHT
var hit_wall: bool = false
## Charges finished so far in this attack.
var charges_done: int = 0

var _line: Line2D = null
var _boost: Dictionary = {}
## True between two charges of a multi-charge ram.
var _pausing: bool = false
var _segment_time: float = 0.0


func _on_telegraph() -> void:
    hit_wall = false
    charges_done = 0
    _show_line()


func _telegraph_tick(_delta: float) -> void:
    _aim_line()


func _on_active() -> void:
    _start_charge()


func _active_tick(delta: float) -> bool:
    _segment_time += delta
    if _pausing:
        _face_target()
        _aim_line()
        if _segment_time >= float(cfg().get("between", 0.5)):
            _start_charge()
        return false
    if boss.get_slide_collision_count() > 0 and _segment_time > 0.05:
        hit_wall = true
        _impact(boss.global_position, "wall")
        return _end_charge()
    boss.velocity = direction * boss.stats.get_movement_speed_px()
    boss.sprite.flip_h = direction.x < 0
    if _segment_time >= float(cfg().get("max_duration", 1.2)):
        return _end_charge()
    return false


func _on_active_end() -> void:
    _free_line()
    _remove_boost()
    boss.velocity = Vector2.ZERO


func _start_charge() -> void:
    _pausing = false
    _segment_time = 0.0
    _free_line()
    _remove_boost()
    _boost = {"movement_speed": {"percent": float(cfg().get("speed_mult", 3.5)) - 1.0}}
    boss.stats.add_modifier(_boost)


## Ends one charge. Returns true when it was the last one.
func _end_charge() -> bool:
    charges_done += 1
    _remove_boost()
    boss.velocity = Vector2.ZERO
    _segment_time = 0.0
    if charges_done >= int(cfg().get("charges", 1)):
        if hit_wall:
            _extra_recover = float(cfg().get("wall_stagger", 1.0))
        return true
    hit_wall = false
    _pausing = true
    _show_line()
    return false


## The line keeps tracking the player until the charge starts; that is when
## the direction locks.
func _aim_line() -> void:
    direction = _aim()
    if _line != null:
        var length := float(cfg().get("line_length", 700.0))
        _line.points = PackedVector2Array([Vector2.ZERO, direction * length])


func _show_line() -> void:
    _free_line()
    _line = Line2D.new()
    _line.width = boss.body_radius() * 2.0
    _line.default_color = Color(1.0, 0.2, 0.15, 0.3)
    _line.z_index = -1
    boss.add_child(_line)
    _aim_line()


func _remove_boost() -> void:
    if not _boost.is_empty():
        boss.stats.remove_modifier(_boost)
        _boost = {}


func _free_line() -> void:
    if _line != null and is_instance_valid(_line):
        _line.queue_free()
    _line = null
