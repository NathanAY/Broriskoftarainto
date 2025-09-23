extends Area2D
class_name Projectile

# New
var pierce_left: int = 0   # how many enemies it can pass through
var properties := {}       # scalable dictionary for future (bounce, chain, etc.)
var base_speed = 300
var direction = Vector2.ZERO
@export var damage: float = 0

var event_manager: EventManager = null

# groups to ignore (friendly fire)
var ignore_groups: Array = []
# Optional target (only used by homing behaviors)
var target: Node = null

func _ready():
    connect("body_entered", Callable(self, "_on_area_entered"))
    # Automatically remove projectile after 2 seconds if it doesn't hit anything
    var timer := Timer.new()
    timer.one_shot = true
    timer.wait_time = 2.0
    add_child(timer)
    timer.timeout.connect(Callable(self, "_on_timeout"))
    timer.start()

func _on_timeout():
    queue_free()

func attachEventManager(em: Node):
    event_manager = em

func set_ignore_groups(groups: Array):
    ignore_groups = groups

func set_properties(dict: Dictionary) -> void:
    properties = dict.duplicate()
    pierce_left = properties.get("pierce", 0)

func _physics_process(delta):
    if direction != Vector2.ZERO:
        global_position += direction * base_speed * delta

func set_direction(target_direction: Vector2):
    direction = target_direction.normalized()
    if not event_manager:
        print("Projectile.gd: no event_manager")

# ✅ new method for assigning a target (used by homing behaviors or effects)
func set_target(t: Node):
    target = t

func _on_area_entered(body):
    for group in ignore_groups:
        if body.is_in_group(group):
            return
    var ignore_enemy: Node = null
    if has_meta("ignore_enemy"):
        var path: NodePath = get_meta("ignore_enemy")
        ignore_enemy = get_node_or_null(path)
    if body == ignore_enemy:
        print("Projectile ignoring enemy:", body.name)
        return
    if body.has_node("Health"):
        do_damage(body)
    else:
        print("Enemy has no Health node!")
    if pierce_left > 0:
        pierce_left -= 1
    else:
        # Let behaviors handle bounce / chain / etc.
        for child in get_children():
            if child.has_method("on_projectile_hit") and child.on_projectile_hit(body):
                return  # ✅ behavior decided what to do (bounce, chain, etc.)
        queue_free()

func do_damage(body):
    var ctx = DamageContext.new()
    ctx.source = self
    ctx.target = body
    ctx.base_amount = damage
    ctx.final_amount = damage
    ctx.tags.append("projectile")
    if event_manager: 
        event_manager.emit_event("before_deal_damage", [{"damage_context": ctx}])
    var bodyHealth: Health = body.get_node("Health")
    bodyHealth.event_manager.emit_event("before_take_damage", [{"damage_context": ctx}])
    bodyHealth.take_damage(ctx)
    if event_manager:
        event_manager.emit_event("after_deal_damage", [{"projectile": self, "body": body, "damage_context": ctx}])
    if event_manager:
        event_manager.emit_event("on_hit", [{"projectile": self, "body": body, "damage_context": ctx}])
