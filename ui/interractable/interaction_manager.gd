# InteractionManager.gd
extends Node
class_name InteractionManager

var interactables: Array[Node] = []
var current: Node = null
@onready var tower: Node2D = get_tree().current_scene.get_node_or_null("Tower")

func register(interactable: Node) -> void:
    if not interactables.has(interactable):
        interactables.append(interactable)

func unregister(interactable: Node) -> void:
    interactables.erase(interactable)

func _unhandled_input(event):
    if not current:
        return
    if event.is_action_pressed("ui_accept"):
        current.default_action()
    elif event.is_action_pressed("ui_cancel"):
        current.cancel_action()

func _process(delta):
    if not tower or interactables.is_empty():
        return
    var closest: Node = null
    var closest_dist := INF
    for i in interactables:
        var dist = tower.global_position.distance_to(i.global_position)
        if dist < i.interaction_radius and dist < closest_dist:
            closest = i
            closest_dist = dist
    # Hide old one if different
    if current and current != closest:
        current.hide_menu()
    current = closest
    if current:
        current.show_menu()
