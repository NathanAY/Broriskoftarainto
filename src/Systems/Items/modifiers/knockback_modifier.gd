extends BaseModifier

@export var display_name: String = "Knockback"

## Meters per second, not pixels per second. `KnockbackController.start_knockback`
## converts at the boundary, so nothing else in the chain touches the scale.
@export var knockback_strength: float = 1.0
# Display trigger: knockback itself is applied on hit (on_attack only
# pre-attaches the behavior to projectiles).
@export var trigger_event: String = "on_hit"
var knockback_duration: float = 0.2

func get_tooltip_stats() -> String:
    return "Knocks back enemies at %s m/s" % str(knockback_strength)

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

    var ctx := data.get("damage_context") as DamageContext
    if ctx == null or not is_instance_valid(ctx.target):
        return
    var body: Node = ctx.target

    # Push away from the holder (melee, aura, contact), or from the projectile.
    var from: Node2D = holder if is_instance_valid(holder) else ctx.source as Node2D
    if ctx.source is Projectile and is_instance_valid(ctx.source):
        # the KnockbackBehavior attached at on_attack already handles
        # projectile hits; avoid double knockback
        if ctx.source.get_node_or_null("KnockbackBehavior") != null:
            return
        from = ctx.source
    if from == null:
        return
    var dir: Vector2 = (body.global_position - from.global_position).normalized()
    if dir != Vector2.ZERO:
        # ensure body can get knockback controller
        var kb = body.get_node_or_null("KnockbackController")
        if not kb:
            kb = KnockbackController.new()
            kb.name = "KnockbackController"
            body.add_child(kb)

        kb.start_knockback(dir * (knockback_strength * active_count), knockback_duration)