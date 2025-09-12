# ItemPickup.gd
# ItemPickup.gd
extends Interactable

@export var item: Item

func _populate_menu(menu: Control):
    var label: Label = menu.get_node("Label")
    label.text = "%s\n%s" % [item.name, item.description]

    var pickup_button: Button = menu.get_node("Button")
    pickup_button.text = "Pick up"
    pickup_button.pressed.connect(_on_pickup)

    var destroy_button: Button = menu.get_node("Button2")
    destroy_button.text = "Destroy"
    destroy_button.pressed.connect(_on_destroy)

func _on_pickup():
    var tower = get_tree().current_scene.get_node_or_null("Tower")
    if not tower:
        return
    var holder = tower.get_node_or_null("ItemHolder")
    if holder:
        holder.add_item(item)
        queue_free()

func _on_destroy():
    queue_free()
