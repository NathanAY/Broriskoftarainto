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
        var inst = melee_scene.instantiate()
        inst.name = node_name
        holder.add_child(inst)

        # Try to find the runtime node that actually implements the weapon API
        var runtime_node: Node = inst
        if not runtime_node.has_method("setup"):
            for child in inst.get_children():
                if child is Node and child.has_method("setup"):
                    runtime_node = child
                    break

        if runtime_node and runtime_node.has_method("setup"):
            runtime_node.call("setup", self, holder, event_manager)
        else:
            push_error("MeleeWeapon: instantiated scene '%s' does not expose 'setup()'" % melee_scene)

        node = runtime_node
    else:
        node = holder.get_node(node_name)

    # Update spawn position at the weapon sprite
    var holder_weapon_holder = holder.get_node("WeaponHolder")
    var sprite_node: Node2D = holder_weapon_holder.weapon_templates.get(self, null)
    if sprite_node:
        node.global_position = sprite_node.global_position
    else:
        node.global_position = holder.global_position

    # Always calculate current target direction
    var target_dir = (targets[0].global_position - node.global_position).normalized()

    # Ensure the node supports attack()
    if node and node.has_method("attack"):
        node.call("attack", target_dir)
    else:
        push_error("MeleeWeapon: runtime node '%s' has no 'attack()' method" % node)
