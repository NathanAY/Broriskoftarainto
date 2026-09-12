# EnemyBehaviour_ChaseNode.gd
extends MovementBehaviour

@export var target: NodePath
@export var stop_distance: float = 32.0  # Distance at which the creature stops moving

func process_movement(creature_self: CharacterBody2D, delta: float) -> void:
    var node = creature_self.target
    if not node:
        return

    var target_pos = node.global_position
    var to_target = target_pos - creature_self.global_position
    var distance = to_target.length()

    if distance <= stop_distance:
        # Close enough → stop moving
        creature_self.velocity = Vector2.ZERO
        creature_self.anim_player.play("idle")
        return

    # Otherwise chase target
    var direction = to_target.normalized()
    var move_speed = creature_self.stats.get_stat("movement_speed")
    creature_self.velocity = direction * move_speed

    creature_self.anim_player.play("move")
    creature_self.sprite.flip_h = direction.x < 0

    creature_self.move_and_slide()
