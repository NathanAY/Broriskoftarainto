# Interactable.gd
extends Area2D
class_name Interactable

@export var interaction_radius: float = 100.0
@onready var tower: Node2D = get_tree().current_scene.get_node_or_null("Tower")

var interaction_menu: Control

func _ready():
    # Create the menu scene but hide it by default
    interaction_menu = preload("res://ui/interractable/InteractionMenu.tscn").instantiate()
    add_child(interaction_menu)
    interaction_menu.visible = false

func _process(delta):
    if not tower:
        return
    
    var distance = global_position.distance_to(tower.global_position)
    if distance <= interaction_radius:
        if not interaction_menu.visible:
            _show_menu()
    else:
        if interaction_menu.visible:
            _hide_menu()

func _show_menu():
    interaction_menu.visible = true
    interaction_menu.global_position = global_position + Vector2(0, -40) # float above object
    _populate_menu(interaction_menu)

func _hide_menu():
    interaction_menu.visible = false

# To be overridden by subclasses (ItemPickup, Chest, etc.)
func _populate_menu(menu: Control):
    pass
