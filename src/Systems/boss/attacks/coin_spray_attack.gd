## Coin Spray: volleys of coins fanned at the player, re-aimed every volley.
## Counterplay: strafe - the fan has gaps at range.
extends BossAttack

var _volleys_left: int = 0
var _until_next: float = 0.0


func _on_active() -> void:
    _volleys_left = int(cfg().get("volleys", 3))
    _until_next = 0.0


func _active_tick(delta: float) -> bool:
    _until_next -= delta
    if _until_next <= 0.0 and _volleys_left > 0:
        _face_target()
        BossBullets.fan(boss, _aim(), int(cfg().get("count", 7)),
                float(cfg().get("spread_deg", 50.0)), float(cfg().get("damage_mult", 1.0)))
        _volleys_left -= 1
        _until_next = float(cfg().get("volley_interval", 0.4))
    return _volleys_left <= 0
