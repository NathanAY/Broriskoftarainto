#Enemy
extends CharacterBody2D

@export var target_position: Vector2 = Vector2.ZERO
var speed = 100

@onready var health_node: Node = $Health  # attach Health.gd as child
@onready var event_manager = $LocalEventManager

signal enemy_died(enemy: CharacterBody2D)

func _ready():
    add_to_group("enemies")  # Add enemy to a group
    event_manager.subscribe("on_death", Callable(self, "on_death"))
    #print("Enemy created at: ", position, " moving toward: ", target_position)

func set_target_position(new_target: Vector2):
    target_position = new_target

func _physics_process(delta):
    if target_position:
        # Calculate direction to target
        var direction = (target_position - global_position).normalized()

        # Set velocity and move
        velocity = direction * speed
        var collision = move_and_slide()

        # Check if we've reached close to the target
        if global_position.distance_to(target_position) < 5:
            queue_free()
            print("Enemy reached target!")
            
func on_death(owner):
    print("Enemy died:", owner)
    # now you can attach modifiers here if needed            
