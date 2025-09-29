extends Node
class_name KnockbackBehavior

@export var knockback_strength: float = 300.0
@export var knockback_duration: float = 0.2

var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
var knockback_duration_internal: float = 0.0
var target: Node2D = null

#func _ready():
    # The parent will be a projectile or melee weapon that attaches this behavior
    #if get_parent().has_method("connect"):
        # If parent is a projectile → listen for hits
        #get_parent().connect("body_entered", Callable(self, "_on_hit"))

func on_projectile_hit(body: Node) -> bool:
    if not body or not body.has_node("Health"):
        return false
    
    var dir = (body.global_position - get_parent().global_position).normalized()
    apply_knockback(body, dir)
    return false   # return true if you want to stop further processing (e.g. for bounce)

func apply_knockback(body: Node2D, direction: Vector2):
    if not body: return
    if not body.has_method("add_child"): return

    # Ensure knockback behavior is unique per body
    var kb = body.get_node_or_null("KnockbackController")
    if not kb:
        kb = KnockbackController.new()
        kb.name = "KnockbackController"
        body.add_child(kb)

    kb.start_knockback(direction * knockback_strength, knockback_duration)

func _on_hit(body: Node):
    if body.has_node("Health"):  # only damageables
        var dir = (body.global_position - get_parent().global_position).normalized()
        apply_knockback(body, dir)
