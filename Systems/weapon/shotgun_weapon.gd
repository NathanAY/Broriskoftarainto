# res://scripts/weapons/ShotgunWeapon.gd
extends ProjectileWeapon
class_name ShotgunWeapon

@export var pellet_count: int = 8
@export var spread_angle: float = 15.0

func try_shoot(targets: Array[Node]) -> void:
    SoundManager.play(attack_sound.pick_random(), -15, 0.2)
    var dir = (targets[0].global_position - sprite_node.global_position).normalized()
    for i in range(pellet_count):
        var p: Projectile = shoot_projectile(targets[0])
        var angle = deg_to_rad(randf_range(-spread_angle, spread_angle))
        var rotated = dir.rotated(angle)
        p.set_direction(rotated)
        p.damage = base_damage / pellet_count * 2
        p.base_speed = randf_range(p.base_speed * 0.9, p.base_speed * 1.1)
