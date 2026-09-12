# StopAtDistance.gd
extends MovementBehaviour

@export var target: NodePath
@export var stop_distance: float = 200.0

func process_movement(creature_self: CharacterBody2D, delta: float) -> void:
    var node = creature_self.target
    if not node: return

    var target_pos = node.global_position
    var dist = creature_self.global_position.distance_to(target_pos)

    if dist > stop_distance:
        var direction = (target_pos - creature_self.global_position).normalized()
        creature_self.velocity = direction * creature_self.stats.get_stat("movement_speed")
        creature_self.anim_player.play("move")
        creature_self.sprite.flip_h = direction.x < 0
    else:
        creature_self.velocity = Vector2.ZERO
        creature_self.anim_player.play("idle")

    creature_self.move_and_slide()
