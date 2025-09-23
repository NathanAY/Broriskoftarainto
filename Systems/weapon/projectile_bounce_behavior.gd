extends Node
class_name ProjectileBounceBehavior

@export var max_bounces: int = 1
@export var bounce_range: float = 1000.0

var holder: Node
var weapon: BaseWeapon
var projectile: Projectile
var bounces_left: int

func _ready():
    projectile = get_parent()
    bounces_left = max_bounces

func on_projectile_hit(hit_body: Node) -> bool:
    if bounces_left <= 0:
        return false  # no bounces left, projectile will be destroyed

    var next_target = _find_next_target(hit_body)
    if not next_target:
        return false  # no target found → projectile will be destroyed

    # redirect projectile
    var dir = (next_target.global_position - projectile.global_position).normalized()
    projectile.set_direction(dir)
    projectile.target = next_target

    bounces_left -= 1
    return true  # ✅ tell projectile “don’t destroy yet”

func _find_next_target(exclude: Node) -> Node:
    if not weapon or not weapon.target_selector:
        return null

    var holder = weapon.get_holder()
    if not holder:
        return null

    var sprite_node: Node2D = weapon.sprite_node
    var candidates = weapon.target_selector.find_targets(sprite_node, bounce_range, holder)

    # Filter out current target
    candidates = candidates.filter(func(t): return t != exclude)

    return candidates[0] if candidates.size() > 0 else null
