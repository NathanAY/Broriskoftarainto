extends Camera2D

@export var target: Node2D  # drag your Tower into inspector
@export var follow_speed: float = 3.0

#func _process(delta):
    #if target:
        #global_position = target.global_position
func _physics_process(delta):
    if target:
        global_position = global_position.lerp(target.global_position, delta * follow_speed)
