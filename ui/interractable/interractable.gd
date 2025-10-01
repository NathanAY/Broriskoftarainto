# Interactable.gd
extends Area2D
class_name Interactable

@export var interaction_radius: float = 100.0
var destroy_timeout = 100 # interractable destroys after 100 seconds
var interaction_menu: Control

func _ready():
    interaction_menu = preload("res://ui/interractable/InteractionMenu.tscn").instantiate()
    add_child(interaction_menu)
    interaction_menu.visible = false

    # Register into manager
    var manager = get_tree().current_scene.get_node("InteractionManager")
    manager.register(self)
    var timer := Timer.new()
    timer.one_shot = true
    timer.wait_time = destroy_timeout
    add_child(timer)
    timer.timeout.connect(Callable(self, "_on_timeout"))
    timer.start()

func _on_timeout():
    queue_free()

func _exit_tree():
    var manager = get_tree().current_scene.get_node_or_null("InteractionManager")
    if manager:
        manager.unregister(self)

func show_menu():
    interaction_menu.visible = true
    interaction_menu.global_position = global_position + Vector2(0, -40)
    _populate_menu(interaction_menu)

func hide_menu():
    interaction_menu.visible = false

func _populate_menu(menu: Control):
    # override in child
    pass
