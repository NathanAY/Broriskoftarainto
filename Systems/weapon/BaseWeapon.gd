# res://scripts/weapons/base_weapon.gd
extends Resource
class_name BaseWeapon

@export var name: String
@export var description: String
@export var base_attack_speed: float = 1.0
@export var base_damage: float = 5.0
@export var range: float = 400.0
@export var modifiers: Dictionary = {}

var holder_ref: WeakRef
var event_manager: Node

func apply_to(holder: Node) -> void:
    holder_ref = weakref(holder)
    event_manager = holder.get_node_or_null("EventManager")

func remove_from(holder: Node) -> void:
    holder_ref = null
    event_manager = null

func get_holder() -> Node:
    return holder_ref.get_ref() if holder_ref and holder_ref.get_ref() else null

# abstract: subclasses override this
func try_shoot(target: Node) -> void:
    push_warning("BaseWeapon: try_shoot not implemented for %s" % name)
