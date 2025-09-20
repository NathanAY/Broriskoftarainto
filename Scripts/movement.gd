extends Node

@onready var anim_player: AnimationPlayer = get_parent().get_node("AnimationPlayer")

func _physics_process(delta: float) -> void:
    var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    var character: CharacterBody2D = get_parent()
    var stats = character.get_node_or_null("Stats")

    var move_speed = 0.0
    if stats:
        move_speed = stats.get_stat("movement_speed")

    character.velocity = input_dir * move_speed
    character.move_and_slide()

    # --- Animation handling ---
    if input_dir.length() > 0.1:
        if anim_player.current_animation != "move":
            anim_player.play("move")
    else:
        if anim_player.current_animation != "idle":
            anim_player.play("idle")
