# res://scripts/Weapon.gd
extends Resource
class_name Weapon

@export var name: String
@export var description: String
@export var projectile_scene: PackedScene
@export var modifiers: Dictionary = {}
@export var base_attack_speed: float = 1.0
@export var base_damage: float = 5.0
@export var range: float = 400.0

var holder_ref: WeakRef = null
var event_manager: Node = null

func apply_to(holder_node: Node) -> void:
    holder_ref = weakref(holder_node)
    event_manager = holder_node.get_node_or_null("EventManager")
    var stats = holder_node.get_node_or_null("Stats")
    if stats and modifiers:
        stats.add_modifier(modifiers)

func remove_from(holder_node: Node) -> void:
    var stats = holder_node.get_node_or_null("Stats")
    if stats and modifiers:
        stats.remove_modifier(modifiers)
    holder_ref = null
    event_manager = null

func get_holder() -> Node:
    if holder_ref and holder_ref.get_ref():
        return holder_ref.get_ref()
    return null

func try_shoot(target: Node) -> void:
    var holder = get_holder()
    if holder == null:
        push_warning("Weapon %s has no valid holder (maybe freed)" % name)
        return

    #print("Weapon ", name, " shooting from", holder.name, "at", target.name)

    if projectile_scene == null:
        push_warning("Weapon %s has no projectile_scene" % name)
        return

    var stats = holder.get_node_or_null("Stats")
    if stats == null:
        return

    var projectile = projectile_scene.instantiate()
    projectile.global_position = holder.global_position

    var direction = (target.global_position - holder.global_position).normalized()
    if projectile.has_method("attachEventManager") and event_manager:
        projectile.attachEventManager(event_manager)
    else:
        print("Weapon.gd: Not event manager") 
    if projectile.has_method("set_direction"):
        projectile.set_direction(direction)
    if projectile.has_method("set_ignore_groups"):
        projectile.set_ignore_groups(holder.get_groups().filter(func(g): return g != "damageable"))
    projectile.damage = stats.get_stat("damage") + base_damage

    holder.get_tree().current_scene.add_child(projectile)

    if event_manager:
        event_manager.emit_event("on_attack", [{"projectile": projectile, "weapon": self}])
