extends BaseModifier

@export var display_name: String = "Knockback"
@export var knockback_strength: float = 300.0
# Display trigger: knockback itself is applied on hit (on_attack only
# pre-attaches the behavior to projectiles).
@export var trigger_event: String = "on_hit"
var knockback_duration: float = 0.2

func get_tooltip_stats() -> String:
    return "Knocks back enemies with %s force" % str(knockback_strength)

func attachEventManager(em: EventManager):
    _cache_holder(em)
    # keep listening to on_attack for projectile-case (attach behavior to projectile)
    _subscribe("on_attack", Callable(self, "_on_attack"))
    # ALSO listen for actual hit events to apply knockback for melee & projectiles
    _subscribe(trigger_event, Callable(self, "_on_hit"))

# Keep previous logic but only handle projectile attaching here
func _on_attack(data: Dictionary):
    var active_count = _active_stacks()

    if data.has("projectile"):
        var projectile: Projectile = data["projectile"]
        # attach projectile behavior node (projectiles are nodes in the scene when fired)
        var behavior = preload("res://src/Systems/weapon/knockback_behavior.gd").new()
        behavior.name = "KnockbackBehavior"
        behavior.knockback_strength = knockback_strength * active_count
        behavior.knockback_duration = knockback_duration
        projectile.add_child(behavior)

# This handles both melee and projectile hits
func _on_hit(data: Dictionary) -> void:
    var active_count = _active_stacks()

    var body: Node = data.get("body", null)
    if not body or not is_instance_valid(body):
        return

    var dir := Vector2.ZERO

    if data.has("projectile"):
        var proj = data["projectile"]
        if proj and is_instance_valid(proj):
            # the KnockbackBehavior attached at on_attack already handles
            # projectile hits; avoid double knockback
            if proj.get_node_or_null("KnockbackBehavior") != null:
                return
            # push away from projectile
            dir = (body.global_position - proj.global_position).normalized()

    elif data.has("melee"):
        var melee_node = data["melee"]
        if melee_node and is_instance_valid(melee_node):
            # flip the direction for melee (push away from the *holder*, not the swing node)
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

        kb.start_knockback(dir * (knockback_strength * active_count), knockback_duration)