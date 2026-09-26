# res://src/scripts/ItemHolder.gd
extends Node
class_name ItemHolder

# try to find Stats + EventManager on the parent (the entity that owns this ItemHolder)
@onready var hold_owner: Node = get_parent()
@onready var stats: Stats = hold_owner.get_node_or_null("Stats")
@onready var event_manager: EventManager = hold_owner.get_node_or_null("EventManager")

@export var items: Array[Item] = []

func add_item(item: Item) -> void:
    if item == null:
        return
    items.append(item)
    if hold_owner == null:
        hold_owner = get_parent()
    if stats == null:
        stats = hold_owner.get_node_or_null("Stats")
    if event_manager == null:
        event_manager = hold_owner.get_node_or_null("EventManager")

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
            effect = BaseModifier.instantiate_attached(effect_scene, self)
            if effect:
                item.apply_to(hold_owner)
                # Modifiers wire through attachEventManager; buffs / poison
                # effects wire themselves in their own _ready.
                if effect.has_method("attachEventManager") and event_manager:
                    effect.attachEventManager(event_manager)
        # Decide stack state
        var active = true
        var scene_conditions: Array[String] = item.effect_scene_condition
        if scene_conditions.size() > 0:
            var condition: String = scene_conditions[0]
            if condition != "" and stats:
                active = stats.get_condition(condition) > 0
                var idx = effect.stacks.size() # about to add
                event_manager.subscribe("on_condition_change", func(ev):
                    if effect.has_method("set_stack_active") and ev["condition_name"] == condition:
                        effect.set_stack_active(idx, stats.get_condition(condition) > 0)
                )

        if effect.has_method("add_stack"):
            effect.add_stack(active)
    else:
        item.apply_to(hold_owner)        

    # Notify others
    if event_manager:
        event_manager.emit_event("on_item_added", {"hold_owner": hold_owner, "item": item, "items": items})
 
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
    # Remove one stack of the matching effect node; detach + free on the last stack
    if item is Item and item.effect_scene:
        var effect_scene = item.effect_scene[0]
        for child in get_children():
            if child.scene_file_path == effect_scene.resource_path:
                if child.has_method("remove_latest_stack"):
                    child.remove_latest_stack()
                if child.stacks.is_empty():
                    if child.has_method("detach"):
                        child.detach()
                    child.queue_free()
                break
    # Remove from list
    items.erase(item)
    # Notify others
    if event_manager:
        event_manager.emit_event("on_item_removed", {"hold_owner": hold_owner, "item": item, "items": items})
