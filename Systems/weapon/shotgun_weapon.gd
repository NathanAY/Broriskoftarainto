# res://scripts/weapons/ShotgunWeapon.gd
extends BaseWeapon
class_name ShotgunWeapon

@export var projectile_scene: PackedScene
@export var pellet_count: int = 8
@export var spread_angle: float = 15.0

func try_shoot(targets: Array[Node]) -> void:
    var holder = get_holder()
    if not holder or not projectile_scene: return

    var dir = (targets[0].global_position - holder.global_position).normalized()
    for i in range(pellet_count):
        var angle = deg_to_rad(randf_range(-spread_angle, spread_angle))
        var rotated = dir.rotated(angle)

        var p: Projectile = projectile_scene.instantiate()
        p.attachEventManager(event_manager)
        p.global_position = holder.global_position
        p.damage = base_damage / pellet_count
        p.base_speed = randf_range(p.base_speed * 0.9, p.base_speed * 1.1)
        if p.has_method("set_ignore_groups"):
            var ignoreGroups = holder.get_groups().filter(func(g): return g != "damageable")
            p.set_ignore_groups(ignoreGroups)
        if p.has_method("set_direction"):
            p.set_direction(rotated)  
        
        holder.get_tree().current_scene.add_child(p)
        event_manager.emit_event("on_attack", [{"projectile": p, "weapon": self}])
