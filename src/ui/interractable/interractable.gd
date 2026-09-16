# Interactable.gd
extends Area2D
class_name Interactable

@export var interaction_radius: float = 100.0
var destroy_timeout = 100 # interractable destroys after 100 seconds
var interaction_menu: Control
var _manager = null

func _ready():
    interaction_menu = preload("res://src/ui/interractable/InteractionMenu.tscn").instantiate()
    add_child(interaction_menu)
    interaction_menu.visible = false

    # Register into manager (deferred: current_scene may not be set yet,
    # e.g. when the scene is instantiated by a test runner).
    call_deferred("_register_to_manager")
    var timer := Timer.new()
    timer.one_shot = true
    timer.wait_time = destroy_timeout
    add_child(timer)
    timer.timeout.connect(Callable(self, "_on_timeout"))
    timer.start()

func _register_to_manager() -> void:
    if not is_inside_tree():
        return
    var manager = null
    var scene_root = get_tree().current_scene
    if scene_root:
        manager = scene_root.get_node_or_null("InteractionManager")
    if manager == null:
        # Fallback: search ancestors for an InteractionManager sibling.
        var parent = get_parent()
        while parent:
            manager = parent.get_node_or_null("InteractionManager")
            if manager:
                break
            parent = parent.get_parent()
    if manager:
        manager.register(self)
        _manager = manager

func _on_timeout():
    queue_free()

func _exit_tree():
    if _manager and is_instance_valid(_manager):
        _manager.unregister(self)
        _manager = null
        return
    if not is_inside_tree():
        return
    var scene_root = get_tree().current_scene
    var manager = scene_root.get_node_or_null("InteractionManager") if scene_root else null
    if manager:
        manager.unregister(self)

func show_menu():
    if interaction_menu.visible:
        return
    interaction_menu.visible = true
    interaction_menu.global_position = global_position + Vector2(0, -40)
    _populate_menu(interaction_menu)

func hide_menu():
    interaction_menu.visible = false

func _populate_menu(_menu: Control):
    # override in child
    pass
