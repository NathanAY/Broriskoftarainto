# res://src/scripts/ItemHolder.gd
extends Node
class_name ItemHolder

# try to find Stats + EventManager on the parent (the entity that owns this ItemHolder)
@onready var hold_owner: Node = get_parent()
@onready var stats: Stats = hold_owner.get_node_or_null("Stats")
@onready var event_manager: EventManager = hold_owner.get_node_or_null("EventManager")

@export var items: Array[Item] = []

# `items` above is the single source of truth. An item is a Resource, so it can
# never be a child itself; `_create_item_node` therefore builds the one node per
# item that represents it in the tree, named after the item ("Boots of speed").

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

    _create_item_node(item)

    if item is Item and item.effect_scene:
        # An item may carry several effects: every scene in `effect_scene` gets
        # its own (deduplicated) effect node and one stack per copy. The item's
        # stat modifiers are applied once per copy, before the first new effect
        # node is wired, so a modifier that owns a stat sees them.
        var modifiers_applied := false
        for i in item.effect_scene.size():
            var effect_scene: PackedScene = item.effect_scene[i]
            if effect_scene == null:
                continue
            # 🔹 Look if we already have an effect of this type
            var effect: Node = _find_effect_node(effect_scene)
            # 🔹 If not found, create new one
            if not effect:
                effect = BaseModifier.instantiate_attached(effect_scene, self)
                if not effect:
                    continue
                if not modifiers_applied:
                    item.apply_to(hold_owner)
                    modifiers_applied = true
                # Modifiers wire through attachEventManager; buffs / poison
                # effects wire themselves in their own _ready.
                if effect.has_method("attachEventManager") and event_manager:
                    effect.attachEventManager(event_manager)
            # Effect i is gated by condition i (an empty entry means always on)
            var condition := ""
            var scene_conditions: Array[String] = item.effect_scene_condition
            if i < scene_conditions.size():
                condition = scene_conditions[i]
            _add_stack(effect, condition)
    else:
        item.apply_to(hold_owner)        

    # Notify others
    if event_manager:
        event_manager.emit_event("on_item_added", {"hold_owner": hold_owner, "item": item, "items": items})

# Give `effect` one stack for the item copy that was just added. The stack starts
# inactive when `condition` does not hold and is kept in sync with it through
# `on_condition_change`; an empty condition means the stack is always active.
func _add_stack(effect: Node, condition: String) -> void:
    if not effect.has_method("add_stack"):
        return
    var active := true
    if condition != "" and stats and event_manager:
        active = stats.get_condition(condition) > 0
        var idx: int = effect.stacks.size() # about to add
        event_manager.subscribe("on_condition_change", func(ev):
            if effect.has_method("set_stack_active") and ev["condition_name"] == condition:
                effect.set_stack_active(idx, stats.get_condition(condition) > 0)
        )
    effect.add_stack(active)

# The single node that represents the item in the scene tree. It is a sibling of
# the item's effect node on purpose: effect nodes are deduplicated per effect
# type and stacked, so one effect node can serve several items and cannot be
# owned by any one of them.
func _create_item_node(item: Item) -> ItemNode:
    var node := ItemNode.new()
    node.name = _unique_item_node_name(item.name)
    node.item = item
    add_child(node)
    return node

# Items are shared Resources, so the holder looks its node up by the item it
# carries instead of keeping a map.
func _find_item_node(item: Item) -> ItemNode:
    for child in get_children():
        if child is ItemNode and (child as ItemNode).item == item:
            return child as ItemNode
    return null

# The already-instantiated effect for `effect_scene`, or null.
#
# Effect nodes are matched by scene path, and both sides of that comparison can
# legitimately be empty: `ItemBuilder.pack_instance` builds in-memory
# PackedScenes with no `resource_path`, and a node instantiated from one has no
# `scene_file_path` either. That empty == empty match is what lets a second item
# of the same type find and stack into the first item's effect node, so it has to
# stay. The per-item ItemNode is script-created and also has an empty
# `scene_file_path`, so it would hijack that match and swallow the real effect -
# it must be skipped explicitly.
func _find_effect_node(effect_scene: PackedScene) -> Node:
    if effect_scene == null:
        return null
    for child in get_children():
        if child is ItemNode:
            continue
        if child.scene_file_path == effect_scene.resource_path:
            return child
    return null

# Godot node names cannot contain . : @ / " % and two holders can hold the same
# item, so a taken name gets a numeric suffix ("Boots of speed", "Boots of
# speed2", ...).
func _unique_item_node_name(item_name: String) -> String:
    var base := ""
    for c in item_name:
        if c not in [".", ":", "@", "/", "\\", "\"", "%"]:
            base += c
    if base.is_empty():
        base = "Item"
    var candidate := base
    var suffix := 2
    while has_node(NodePath(candidate)):
        candidate = "%s%d" % [base, suffix]
        suffix += 1
    return candidate

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
    # Remove one stack of every matching effect node; detach + free on the last stack
    if item is Item and item.effect_scene:
        for effect_scene in item.effect_scene:
            if effect_scene == null:
                continue
            var effect: Node = _find_effect_node(effect_scene)
            if effect:
                if effect.has_method("remove_latest_stack"):
                    effect.remove_latest_stack()
                if effect.stacks.is_empty():
                    if effect.has_method("detach"):
                        effect.detach()
                    effect.queue_free()
    # Remove the tree node that represents the item
    var item_node := _find_item_node(item as Item)
    if item_node:
        item_node.queue_free()
    # Remove from list
    items.erase(item)
    # Notify others
    if event_manager:
        event_manager.emit_event("on_item_removed", {"hold_owner": hold_owner, "item": item, "items": items})
