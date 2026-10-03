#character.gd
extends CharacterBody2D
class_name Character

# Resolved on access rather than with `@onready`. `@onready` waits for `_ready`, so
# these all read as null while the character is detached - and a scene's root node
# runs its member initializers *before* its children are attached, so a plain
# initializer would be null too. A getter runs after the children exist, which
# makes a detached-but-fully-built character usable: the shop builds one off-tree
# and equips items and weapons into it before it ever enters the scene.
var event_manager: EventManager:
    get:
        return get_node_or_null("EventManager") as EventManager

var item_holder: ItemHolder:
    get:
        return get_node_or_null("ItemHolder") as ItemHolder

var stats: Stats:
    get:
        return get_node_or_null("Stats") as Stats

var weapon_holder: WeaponHolder:
    get:
        return get_node_or_null("WeaponHolder") as WeaponHolder

var anim_player: AnimationPlayer:
    get:
        return get_node_or_null("AnimationPlayer") as AnimationPlayer

var current_target = null
var fire_timer = 0.0

signal character_died

func _ready():
    add_to_group("character")
    add_to_group("damageable")
    for c in get_children():
        if c.has_method("attachEventManager"):
            c.attachEventManager(event_manager)

    GlobalGameState.current_character = self
    var weapons = GlobalGameState.starting_weapons
    for weapon_path in weapons:
        weapon_holder.add_weapon(load(weapon_path))
    # Items
    var items = GlobalGameState.starting_items
    for item_path in items:
        item_holder.add_item(load(item_path)) 
    
    collision_layer = 1
    # Only collide with arena walls (layer 4) — stays inside the ground.
    # Hit detection goes through the Hitbox Area2D, not the body.
    collision_mask = Arena.WALL_LAYER_BIT
    
    $Hitbox.collision_layer = 3
    $Hitbox.collision_mask = 7
    event_manager.subscribe("on_death", Callable(self, "_die"))

func _on_area_2d_area_entered(area: Area2D) -> void:
    if area.get_parent().is_in_group("enemies"):
        area.get_parent().queue_free()
        print("Enemy destroyed!")  

func _die(_event: Dictionary):
    emit_signal("character_died")
    queue_free()

func _exit_tree() -> void:
    if GlobalGameState.current_character == self:
        GlobalGameState.current_character = null
