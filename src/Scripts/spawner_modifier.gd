#spawner_modifier.gd
extends Node

@export var pickup_scene: PackedScene = preload("res://src/Systems/Items/ItemPickup.tscn")
@export var altar_scene: PackedScene = preload("res://src/Systems/altars/ItemSacrificeAltar.tscn")
@export var heal_scene: PackedScene = preload("res://src/Systems/Items/HealPickup.tscn")
const HEAL_DROP_CHANCE := 0.08
@export var itemFactory: ItemFactory = null

var randomGenerator = RandomNumberGenerator.new()
var character: Character = null

func attach_to_enemy(enemy: Node, new_character: Character):
    var health: Health = enemy.get_node_or_null("Health")
    character = new_character
    if health and health.event_manager:
        health.event_manager.subscribe("on_death", Callable(self, "attach_on_death_effects"))
    else:
        push_warning("ExplosionModifier: Entity has no Health or EventManager!")

func attach_on_death_effects(event: Dictionary):
    # award money to character
    if character and character.stats:
        character.stats.set_base_stat("money", character.stats.stats.get("money", 0) + 1)
    # Use deferred spawn to avoid physics flushing error
    call_deferred("_spawn_item", event.get("self").global_position)
    DeathMark.leave_corpse(event.get("self"))

func _spawn_item(position: Vector2):
    # Generate alter 5%, item drop chance 5%
    if randf() < 0.05:
        var altar: ItemSacrificeAltar = altar_scene.instantiate()
        altar.add_item(itemFactory.get_item_from_pool_or_generate())
        altar.global_position = position
        get_tree().current_scene.get_node("Nodes/altars").add_child(altar)
    elif randf() < 0.05:
        var item = itemFactory.get_item_from_pool_or_generate()
        var pickup = pickup_scene.instantiate()
        pickup.global_position = position
        pickup.item = item
        get_tree().current_scene.get_node("Nodes/pickups").add_child(pickup)
    elif randf() < HEAL_DROP_CHANCE:
        var heal = heal_scene.instantiate()
        heal.global_position = position
        get_tree().current_scene.get_node("Nodes/pickups").add_child(heal)

