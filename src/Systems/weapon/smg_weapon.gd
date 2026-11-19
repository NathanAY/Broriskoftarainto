extends ProjectileWeapon
class_name SmgWeapon

## Each bullet leaves up to this many degrees off the aim line, either side.
## It is what the SMG pays for its fire rate: at range, a share of the burst misses.
@export var spread_angle: float = 8.0

func tooltip_details() -> Array:
    var details := super.tooltip_details()
    details.append(["Spread", "±%d°" % int(spread_angle)])
    return details

func try_shoot(targets: Array[Node]) -> void:
    SoundManager.play(attack_sound.pick_random(), -15, 0.2)
    var p: Projectile = shoot_projectile(targets[0])
    if p == null:
        return
    var dir: Vector2 = (targets[0].global_position - sprite_node.global_position).normalized()
    p.set_direction(dir.rotated(deg_to_rad(randf_range(-spread_angle, spread_angle))))
