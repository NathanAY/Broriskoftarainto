#character.gd
extends CharacterBody2D
class_name Character

@onready var event_manager: EventManager = $EventManager
@onready var item_holder: ItemHolder = $ItemHolder
@onready var stats: Stats = $Stats
@onready var weapon_holder: WeaponHolder = $WeaponHolder
@onready var anim_player: AnimationPlayer = $AnimationPlayer

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
        $WeaponHolder.add_weapon(load(weapon_path))
    # Items
    var items = GlobalGameState.starting_items
    for item_path in items:
        $ItemHolder.add_item(load(item_path)) 
    
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
