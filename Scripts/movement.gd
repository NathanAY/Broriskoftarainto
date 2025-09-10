extends Node

func _physics_process(delta: float) -> void:
    var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    var character: CharacterBody2D = get_parent()
    # If you have "speed" in Stats, use it
    var move_speed = character.get_node_or_null("Stats").get_stat("movement_speed")
    character.velocity = input_dir * move_speed
    character.move_and_slide()
