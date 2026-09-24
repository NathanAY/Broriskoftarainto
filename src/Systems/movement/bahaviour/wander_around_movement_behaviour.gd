# EnemyBehaviour_WanderNode.gd
extends MovementBehaviour

@export var target: NodePath
@export var wander_radius: float = 200.0
@export var reach_threshold: float = 20.0
## Keep wander goals this far from the ground edge so big bodies (boss
## radius ~61px) can actually reach the point instead of sliding on the wall.
@export var edge_margin: float = 50.0
## Optional arena reference. Auto-resolved from the "arena" group when null.
## When no arena exists (scenes without ground), goals stay unclamped.
@export var arena: Arena

var current_goal: Vector2 = Vector2.ZERO
var flip_sprite: bool = true

func process_movement(creature_self: CharacterBody2D, _delta: float) -> void:
    if current_goal == Vector2.ZERO:
        _pick_new_goal(creature_self)
        return

    if creature_self.global_position.distance_to(current_goal) < reach_threshold:
        _pick_new_goal(creature_self)

    var direction = (current_goal - creature_self.global_position).normalized()
    creature_self.velocity = direction * creature_self.stats.get_movement_speed_px()
    creature_self.anim_player.play("move")
    creature_self.sprite.flip_h = direction.x < 0

func _pick_new_goal(creature_self: CharacterBody2D):
    var center: Vector2
    # If creature_self has a valid target property, use it
    if creature_self.get("target") and is_instance_valid(creature_self.target):
        center = creature_self.target.global_position
    else:
        # Otherwise wander around itself
        center = creature_self.global_position
        # not flip sprite because player not no sprite in creature_self
        flip_sprite = false

    var angle = randf() * TAU
    var offset = Vector2(cos(angle), sin(angle)) * randf_range(50, wander_radius)
    current_goal = center + offset
    current_goal = clamp_goal_to_arena(current_goal)


func clamp_goal_to_arena(pos: Vector2) -> Vector2:
    var found_arena := _get_arena()
    if found_arena == null or not is_instance_valid(found_arena):
        return pos
    return found_arena.clamp_to_arena(pos, edge_margin)


func _get_arena() -> Arena:
    if arena != null and is_instance_valid(arena):
        return arena
    if is_inside_tree():
        arena = get_tree().get_first_node_in_group("arena") as Arena
    return arena
