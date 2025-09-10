# res://scripts/ItemHolder.gd
extends Node
class_name ItemHolder

# try to find Stats + EventManager on the parent (the entity that owns this ItemHolder)
@onready var hold_owner: Node = get_parent()
@onready var stats: Node = hold_owner.get_node_or_null("Stats")
@onready var event_manager: Node = hold_owner.get_node_or_null("EventManager")

@export var items: Array = []

func add_item(item: Resource) -> void:
    if item == null:
        return
    items.append(item)

    if item is Item and item.effect_scene:
        var effect_scene = item.effect_scene[0]
        var effect: Node = null
        # 🔹 Look if we already have an effect of this type
        for child in get_children():
            if child.scene_file_path == effect_scene.resource_path:
                effect = child
                break
        # 🔹 If not found, create new one
        if not effect:
            effect = effect_scene.instantiate()
            add_child(effect)
            item.apply_to(hold_owner)
            if effect.has_method("attachEventManager") and event_manager:
                effect.attachEventManager(event_manager)
        # 🔹 Update stacks if SpreadModifier
        if effect.has_method("add_stack"):
            effect.add_stack(1)
    else:
        item.apply_to(hold_owner)        

    # Notify others
    if event_manager:
        event_manager.emit_event("on_item_added", [{"hold_owner": hold_owner, "item": item, "items": items}])

func remove_item(item: Resource) -> void:
    if not item:
        return
    if not (item in items):
        return
    # Remove stat modifiers
    if item is Item:
        item.remove_from(hold_owner)
    elif item.has_method("remove_from"):
        item.remove_from(hold_owner)
    # Remove from list
    items.erase(item)
    # Notify others
    if event_manager:
        event_manager.emit_event("on_item_removed", [hold_owner, item])
