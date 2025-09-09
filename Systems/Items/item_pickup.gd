# ItemPickup.gd
extends Area2D

@export var item: Resource  # assign ExplosionShotItem.tres

func _ready():
    connect("input_event", Callable(self, "_on_input_event"))

func _on_input_event(viewport, event, shape_idx):
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _give_item_to_tower()
        queue_free()

func _give_item_to_tower():
    var tower = get_tree().current_scene.get_node_or_null("Tower") # adjust path
    if not tower:
        push_warning("ItemPickup: No Tower found in scene!")
        return
    var holder = tower.get_node_or_null("ItemHolder")
    if holder:
        holder.add_item(item)
