# ExplosionModifier.gd
extends Node

@export var explosion_scene = preload("res://Scenes/Explosion.tscn")
@export var pickup_scene: PackedScene = preload("res://Systems/Items/ItemPickup.tscn")
@export var possible_items: Array[Resource] = []

var randomGenerator = RandomNumberGenerator.new()

func attach_to_enemy(entity: Node):
    #print("ExplosionModifier attach_to_enemy")
    #enemy.connect("enemy_died", Callable(self, "_on_enemy_died"))
    var health: Node = entity.get_node_or_null("Health")
    if health and health.event_manager:
        health.event_manager.subscribe("on_death", Callable(self, "explode"))
    else:
        push_warning("ExplosionModifier: Entity has no Health or EventManager!")

func explode(enemy: Node):
    if explosion_scene == null:
        push_warning("ExplosionModifier: explosion_scene not assigned!")
        return
    # Use deferred spawn to avoid physics flushing error
    call_deferred("_spawn_explosion", enemy.global_position)

func _spawn_explosion(position: Vector2):
    var explosion = explosion_scene.instantiate()
    explosion.global_position = position
    get_tree().current_scene.add_child(explosion)

    if (randomGenerator.randfn() < 0.1):
        return
    var random_item: Resource = possible_items[randi() % possible_items.size()]
    var pickup = pickup_scene.instantiate()
    pickup.global_position = position
    pickup.item = random_item
    get_tree().current_scene.add_child(pickup)
