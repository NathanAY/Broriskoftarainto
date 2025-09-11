# res://scripts/weapons/PistolWeapon.gd
extends BaseWeapon
class_name PistolWeapon

@export var projectile_scene: PackedScene

func try_shoot(target: Node) -> void:
    var holder = get_holder()
    if not holder or not projectile_scene: return
    
    var p: Projectile = projectile_scene.instantiate()
    p.attachEventManager(event_manager)
    p.global_position = holder.global_position
    p.damage = base_damage
    if p.has_method("set_ignore_groups"):
        var ignoreGroups = holder.get_groups().filter(func(g): return g != "damageable")
        p.set_ignore_groups(ignoreGroups)
    if p.has_method("set_direction"):
        var dir = (target.global_position - holder.global_position).normalized()
        p.set_direction(dir)
    
    
    holder.get_tree().current_scene.add_child(p)
    event_manager.emit_event("on_attack", [{"projectile": p, "weapon": self}])
