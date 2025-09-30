extends Node
class_name ProjectileBounceBehavior

@export var max_bounces: int = 300
@export var bounce_range: float = 1000.0
@export var target_selector: TargetSelector   # ✅ direct reference

var holder: Node
var projectile: Projectile
var bounces_left: int

# Keep only a short history (last two hits)
var hit_history: Array[Node] = []

func _ready():
    projectile = get_parent()
    bounces_left = max_bounces

func on_projectile_hit(hit_body: Node) -> bool:
    if bounces_left <= 0:
        return false

    if hit_body and is_instance_valid(hit_body):
        hit_history.append(hit_body)
        if hit_history.size() > 2:
            hit_history.pop_front()

    var next_target = _find_next_target(hit_body)
    var dir: Vector2

    if next_target:
        dir = (next_target.global_position - projectile.global_position).normalized()
        projectile.target = next_target
    else:
        # random fallback
        var angle = randf_range(0.0, TAU)
        dir = Vector2(cos(angle), sin(angle)).normalized()
        projectile.target = null

    projectile.set_direction(dir)
    bounces_left -= 1
    return true

func _find_next_target(exclude: Node) -> Node:
    if not target_selector:
        return null

    var holder_node = holder
    if not holder_node:
        return null

    var sprite_node: Node2D = holder_node.get_node_or_null("Sprite") if holder_node else null
    if not sprite_node:
        sprite_node = holder_node

    var candidates = target_selector.find_targets(exclude, bounce_range, holder_node)

    # Filter out: current target + last 2 hits
    candidates = candidates.filter(
        func(t): return not hit_history.has(t) and t != exclude
    )
    return candidates[0] if candidates.size() > 0 else null
