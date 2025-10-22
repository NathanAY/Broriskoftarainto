# res://scripts/weapons/projectile_weapon.gd
extends BaseWeapon
class_name ProjectileWeapon

@export var projectile_scene: PackedScene

var _current_projectile_speed_multiplier: int = 1

func try_shoot(targets: Array[Node]) -> void:
    SoundManager.play(attack_sound.pick_random(), -10, 0.2)
    shoot_projectile(targets[0])

func shoot_projectile(target: Node) -> Projectile:
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
    var projectile_props = {
        "pierce": stats.get_stat("projectile_pierce") if stats.get_stat("projectile_pierce") else 0,
        "bounce": stats.get_stat("projectile_bounce") if stats.get_stat("projectile_bounce") else 0,
        "chain": stats.get_stat("projectile_chain") if stats.get_stat("projectile_chain") else 0
    }
    p.set_properties(projectile_props)
    
    p.base_speed = p.base_speed * _current_projectile_speed_multiplier
    p.damage = _current_damage
    if p.has_method("set_ignore_groups"):
        var ignoreGroups = holder.get_groups().filter(func(g): return g != "damageable")
        p.set_ignore_groups(ignoreGroups)
    if p.has_method("set_direction"):
        var dir = (target.global_position - sprite_node.global_position).normalized()
        p.set_direction(dir)
        p.set_target(target)
    
    holder.get_tree().current_scene.add_child(p)
    event_manager.emit_event("on_attack", [{"projectile": p, "weapon": self}])
    return p

func _on_stat_changes(_event) -> void:
    super._on_stat_changes(_event)
    _current_projectile_speed_multiplier = stats.get_stat("projectile_speed_multiplier")
    
