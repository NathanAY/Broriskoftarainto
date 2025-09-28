# EnemyBehaviour_WanderNode.gd
extends MovementBehaviour

@export var target: NodePath
@export var wander_radius: float = 200.0
@export var reach_threshold: float = 20.0

var current_goal: Vector2 = Vector2.ZERO
var flip_sprite: bool = true

func process_movement(creature_self: CharacterBody2D, delta: float) -> void:
    if current_goal == Vector2.ZERO:
        _pick_new_goal(creature_self)
        return

    if creature_self.global_position.distance_to(current_goal) < reach_threshold:
        _pick_new_goal(creature_self)

    var direction = (current_goal - creature_self.global_position).normalized()
    creature_self.velocity = direction * creature_self.stats.get_stat("movement_speed")
    creature_self.anim_player.play("move")
    creature_self.sprite.flip_h = direction.x < 0
    creature_self.move_and_slide()

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
