#spawner_modifier.gd
extends Node

@export var explosion_scene = preload("res://Scenes/Explosion.tscn")
@export var pickup_scene: PackedScene = preload("res://Systems/Items/ItemPickup.tscn")
@export var altar_scene: PackedScene = preload("res://Systems/altars/ItemSacrificeAltar.tscn")
@export var death_mark_scene: PackedScene = preload("res://Systems/damage/DeathMarkX.tscn")

@export var possible_items: Array[Resource] = []
@onready var itemFactory: ItemFactory = $ItemFactory

var randomGenerator = RandomNumberGenerator.new()

func attach_to_enemy(entity: Node):
    var health: Health = entity.get_node_or_null("Health")
    if health and health.event_manager:
        health.event_manager.subscribe("on_death", Callable(self, "attach_effects"))
    else:
        push_warning("ExplosionModifier: Entity has no Health or EventManager!")

func attach_effects(event: Dictionary):
    if explosion_scene == null:
        push_warning("ExplosionModifier: explosion_scene not assigned!")
        return
    # Use deferred spawn to avoid physics flushing error
    call_deferred("_spawn_explosion", event.get("self").global_position)
    call_deferred("_spawn_item", event.get("self").global_position)
    call_deferred("_spawn_death_mark", event.get("self").global_position)

func _spawn_explosion(position: Vector2):
    var explosion = explosion_scene.instantiate()
    explosion.global_position = position
    get_tree().current_scene.add_child(explosion)

func _spawn_item(position: Vector2):
    # Generate alter 10%, item drop chance 90%
    if randf() < 0.1:
        var altar: ItemSacrificeAltar = altar_scene.instantiate()
        altar.add_item(itemFactory.get_item_from_pool_or_generate())
        altar.global_position = position
        get_tree().current_scene.get_node("Nodes/altars").add_child(altar)
    else:
        var item = itemFactory.get_item_from_pool_or_generate()
        if not item:
            return

        var pickup = pickup_scene.instantiate()
        pickup.global_position = position
        pickup.item = item
        get_tree().current_scene.get_node("Nodes/pickups").add_child(pickup)

func _spawn_death_mark(position: Vector2):
    if death_mark_scene == null:
        push_warning("DeathMarkModifier: death_mark_scene not assigned!")
        return
    var mark = death_mark_scene.instantiate()
    mark.global_position = position
    # Add to a specific node for organization
    var parent_node = get_tree().current_scene.get_node_or_null("Nodes/death_marks")
    if not parent_node:
        parent_node = Node2D.new()
        parent_node.name = "death_marks"
        get_tree().current_scene.add_child(parent_node)
    parent_node.add_child(mark)
