## Coin Spiral: spins in place and fires `arms` coins every `interval`, the
## arms turning by `turn_deg` each shot, for `duration` seconds.
## Counterplay: circle with the spiral, or get close where the arms are wide.
extends BossAttack

var _angle: float = 0.0
var _until_next: float = 0.0


func _on_active() -> void:
    _angle = _aim().angle()
    _until_next = 0.0


func _active_tick(delta: float) -> bool:
    _until_next -= delta
    var arms := int(cfg().get("arms", 2))
    while _until_next <= 0.0:
        for i in arms:
            BossBullets.fire(boss, Vector2.from_angle(_angle + TAU * i / float(arms)),
                    float(cfg().get("damage_mult", 1.0)), float(cfg().get("speed_mult", 1.0)))
        _angle += deg_to_rad(float(cfg().get("turn_deg", 14.0)))
        _until_next += maxf(float(cfg().get("interval", 0.12)), 0.02)
    return _time >= float(cfg().get("duration", 3.0))
