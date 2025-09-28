# EnemyBehaviour_ChaseNode.gd
extends MovementBehaviour

@export var target: NodePath

func process_movement(creature_self: CharacterBody2D, delta: float) -> void:
    var node = creature_self.target
    if not node: return

    var target_pos = node.global_position
    var direction = (target_pos - creature_self.global_position).normalized()
    creature_self.velocity = direction * creature_self.stats.get_stat("movement_speed")

    # Anim + flip
    if direction.length() < 0.1:
        creature_self.anim_player.play("idle")
    else:
        creature_self.anim_player.play("move")
        creature_self.sprite.flip_h = direction.x < 0
    creature_self.move_and_slide()
