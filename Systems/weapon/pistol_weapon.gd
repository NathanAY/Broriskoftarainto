# res://scripts/weapons/PistolWeapon.gd
extends BaseWeapon
class_name PistolWeapon

@export var projectile_scene: PackedScene

func try_shoot(targets: Array[Node]) -> void:
    var holder = get_holder()
    if not holder or not projectile_scene: return
    
    var p: Projectile = projectile_scene.instantiate()
    
    # get weapon’s sprite node
    var holder_weapon_holder = holder.get_node("WeaponHolder")
    var sprite_node: Node2D = holder_weapon_holder.weapon_templates.get(self, null)

    if sprite_node:
        p.global_position = sprite_node.global_position
    else:
        p.global_position = holder.global_position
    
    p.attachEventManager(event_manager)
    p.damage = base_damage
    if p.has_method("set_ignore_groups"):
        var ignoreGroups = holder.get_groups().filter(func(g): return g != "damageable")
        p.set_ignore_groups(ignoreGroups)
    if p.has_method("set_direction"):
        var dir = (targets[0].global_position - holder.global_position).normalized()
        p.set_direction(dir)
        p.set_target(targets[0])
    
    holder.get_tree().current_scene.add_child(p)
    event_manager.emit_event("on_attack", [{"projectile": p, "weapon": self}])
