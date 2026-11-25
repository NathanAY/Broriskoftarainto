## Dividend Ring: one slow ring of coins outward, with a gap aimed at the
## player. Counterplay: walk into the gap, or outrun the ring.
extends BossAttack


func _on_active() -> void:
    BossBullets.ring(boss, int(cfg().get("count", 20)), int(cfg().get("gap", 2)), _aim(),
            float(cfg().get("damage_mult", 1.0)), float(cfg().get("speed_mult", 0.8)))
