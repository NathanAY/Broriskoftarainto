# res://scripts/weapons/LaserWeapon.gd
extends BaseWeapon
class_name LaserWeapon

@export var laser_scene: PackedScene  # could be a Line2D or Area2D scene

func try_shoot(target: Node) -> void:
    var holder = get_holder()
    if not holder or not laser_scene: return

    var beam = laser_scene.instantiate()
    beam.global_position = holder.global_position
    beam.look_at(target.global_position)

    holder.get_tree().current_scene.add_child(beam)
    event_manager.emit_event("on_attack", [{"beam": beam, "weapon": self}])
