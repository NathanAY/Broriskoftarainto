extends Node
class_name KnockbackModifier

@export var knockback_strength: float = 300.0
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
var knockback_duration: float = 0.2

var holder: Node
var event_manager: EventManager
var stacks: Array[bool] = []

func attachEventManager(em: EventManager):
    event_manager = em
    holder = em.get_parent()
    # keep listening to on_attack for projectile-case (attach behavior to projectile)
    event_manager.subscribe("on_attack", Callable(self, "_on_attack"))
    # ALSO listen for actual hit events to apply knockback for melee & projectiles
    event_manager.subscribe("on_hit", Callable(self, "_on_hit"))

func add_stack(active: bool):
    stacks.append(active)

func remove_stack(index: int):
    if index >= 0 and index < stacks.size():
        stacks.remove_at(index)

func set_stack_active(index: int, active: bool):
    if index >= 0 and index < stacks.size():
        stacks[index] = active

# Keep previous logic but only handle projectile attaching here
func _on_attack(data: Dictionary):
    var active_count = stacks.count(true)
    if active_count <= 0:
        return

    if data.has("projectile"):
        var projectile: Projectile = data["projectile"]
        # attach projectile behavior node (projectiles are nodes in the scene when fired)
        var behavior = preload("res://Systems/weapon/knockback_behavior.gd").new()
        behavior.knockback_strength = knockback_strength
        behavior.knockback_duration = knockback_duration
        projectile.add_child(behavior)
    # DO NOT try to add_child to 'weapon' (it's a Resource) — removed that branch.

# This handles both melee and projectile hits
func _on_hit(data: Dictionary) -> void:
    var active_count = stacks.count(true)
    if active_count <= 0:
        return

    var body: Node = data.get("body", null)
    if not body or not is_instance_valid(body):
        return

    var dir := Vector2.ZERO

    if data.has("projectile"):
        var proj = data["projectile"]
        if proj and is_instance_valid(proj):
            # ✅ push away from projectile
            dir = (body.global_position - proj.global_position).normalized()

    elif data.has("melee"):
        var melee_node = data["melee"]
        if melee_node and is_instance_valid(melee_node):
            # ✅ flip the direction for melee (push away from the *holder*, not the swing node)
            if holder and is_instance_valid(holder):
                dir = (body.global_position - holder.global_position).normalized()
            else:
                dir = (body.global_position - melee_node.global_position).normalized()
    else:
        var ctx = data.get("damage_context", null)
        if ctx and ctx.source and is_instance_valid(ctx.source) and ctx.source is Node:
            var src = ctx.source
            dir = (body.global_position - src.global_position).normalized()
    if dir != Vector2.ZERO:
        # ensure body can get knockback controller
        var kb = body.get_node_or_null("KnockbackController")
        if not kb:
            kb = KnockbackController.new()
            kb.name = "KnockbackController"
            body.add_child(kb)

        kb.start_knockback(dir * knockback_strength, knockback_duration)
