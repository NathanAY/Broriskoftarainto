# res://src/scripts/weapons/projectile_weapon.gd
extends BaseWeapon
class_name ProjectileWeapon

@export var projectile_scene: PackedScene

## Muzzle speed for this weapon's projectiles, in **meters per second**, the same
## unit `weapon_range` uses. `0` keeps the projectile scene's own speed (px/s),
## which is what the shared scenes author. Converted with `Stats.meters_to_px` at
## the same boundary as `weapon_range`, so a designer tunes both in meters.
@export var projectile_speed: float = 0.0

var _current_projectile_speed_multiplier: float = 1

func try_shoot(targets: Array[Node]) -> void:
    SoundManager.play(attack_sound.pick_random(), -20, 0.2)
    shoot_projectile(targets[0])

## Projectiles one attack fires. A pellet weapon overrides it; the Miner's mine
## reads it to know how many shots a stretch of time is worth.
func projectiles_per_attack() -> int:
    return 1

func shoot_projectile(target: Node) -> Projectile:
    var holder = get_holder()
    if not holder or not projectile_scene: return
    var from: Vector2 = sprite_node.global_position if sprite_node else holder.global_position
    var p := spawn_projectile(from, (target.global_position - from).normalized())
    p.set_target(target)
    event_manager.emit_event("on_attack", {"projectile": p, "weapon": self})
    return p

## A projectile of this weapon at `from` flying along `dir`, fully configured
## (stats, pierce, damage, friendly fire) and added to the scene. Emits nothing:
## `shoot_projectile` reports the attack, a mine detonation does not.
func spawn_projectile(from: Vector2, dir: Vector2) -> Projectile:
    var holder = get_holder()
    if not holder or not projectile_scene: return null

    var p: Projectile = projectile_scene.instantiate()
    p.global_position = from
    p.attachEventManager(event_manager)
    var projectile_props = {
        "pierce": stats.get_stat("projectile_pierce") if stats.get_stat("projectile_pierce") else 0.0,
        "bounce": stats.get_stat("projectile_bounce") if stats.get_stat("projectile_bounce") else 0.0,
        "chain": stats.get_stat("projectile_chain") if stats.get_stat("projectile_chain") else 0.0
    }
    var spawn_mods := WeaponBuiltinEffects.get_spawn_time_modifiers(self)
    for key in spawn_mods:
        projectile_props[key] = projectile_props.get(key, 0.0) + spawn_mods[key]
    p.set_properties(projectile_props)
    
    if projectile_speed > 0.0:
        p.base_speed = Stats.meters_to_px(projectile_speed)
    p.base_speed = p.base_speed * _current_projectile_speed_multiplier
    p.damage = current_damage
    if p.has_method("set_ignore_groups"):
        var ignoreGroups = holder.get_groups().filter(func(g): return g != "damageable")
        p.set_ignore_groups(ignoreGroups)
    p.set_direction(dir)
    p.source_weapon = self
    holder.get_tree().current_scene.add_child(p)
    return p

func _on_stat_changes(_event) -> void:
    super._on_stat_changes(_event)
    _current_projectile_speed_multiplier = stats.get_stat("projectile_speed_multiplier")
    
