#projectile.gd
extends Area2D

var speed = 300
var direction = Vector2.ZERO
@export var damage: float = 0  # now set by the tower

var event_manager = null

# New: groups to ignore (friendly fire)
var ignore_groups: Array = []

func _ready():
    #emit_signal("projectile_created", self)
    connect("body_entered", Callable(self, "_on_area_entered"))
#	body_entered.connect(_on_body_entered)
    # Automatically remove projectile after 2 seconds if it doesn't hit anything
    await get_tree().create_timer(2.0).timeout
    queue_free()

func attachEventManager(em: Node):
    event_manager = em

func set_ignore_groups(groups: Array):
    ignore_groups = groups

func _physics_process(delta):
    if direction != Vector2.ZERO:
        global_position += direction * speed * delta

func set_direction(target_direction: Vector2):
    direction = target_direction.normalized()
    if not event_manager:
        print("Projectile.gd: no event_manage")

func _on_area_entered(body):
    #print("Projectile hit!" + body.name)
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
    if event_manager:
        event_manager.emit_event("projectile_hit", [self, body])
    # Here you would typically damage the enemy
    #print("Projectile hit enemy!")
    if body.has_node("Health"):
        var health_node = body.get_node("Health")
        health_node.take_damage(damage)
    else:
        print("Enemy has no Health node!")
    queue_free()  # Remove the projectile
