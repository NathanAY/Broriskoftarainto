# res://scripts/weapons/MeleeWeapon.gd
extends BaseWeapon
class_name MeleeWeapon

@export var radius: float = 80.0

func try_shoot(target: Node) -> void:
    var holder = get_holder()
    if not holder: return
#    TODO: implement
    for node in holder.get_tree().get_nodes_in_group("damageable"):
        if node == holder: continue
        var dist = holder.global_position.distance_to(node.global_position)
        if dist <= radius:
            if node.has_node("Health"):
                node.get_node("Health").take_damage(base_damage)
                event_manager.emit_event("on_attack", [{"weapon": self}])
    
