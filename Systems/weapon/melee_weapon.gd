extends BaseWeapon
class_name MeleeWeapon

@export var melee_scene: PackedScene   # scene for the runtime node

func try_shoot(targets: Array[Node]) -> void:
    var holder = get_holder()
    if not holder or not melee_scene: return
    if targets.size() == 0: return

    # Use weapon instance id to make node unique
    var node_name = "%s_Node_%s" % [name, str(self.get_instance_id())]
    var node: Node2D

    if not holder.has_node(node_name):
        node = melee_scene.instantiate()
        node.name = node_name
        holder.add_child(node)
        node.call("setup", self, holder, event_manager)
    else:
        node = holder.get_node(node_name)

    # Update spawn position at the weapon sprite
    var holder_weapon_holder = holder.get_node("WeaponHolder")
    var sprite_node: Node2D = holder_weapon_holder.weapon_templates.get(self, null)
    node.global_position = sprite_node.global_position if sprite_node else holder.global_position

    # Always calculate current target direction
    var target_dir = (targets[0].global_position - node.global_position).normalized()
    node.call("attack", target_dir)
