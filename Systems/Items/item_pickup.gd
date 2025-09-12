# ItemPickup.gd
extends Interactable

@export var item: Item

func _ready():
    super._ready()
    var menu = interaction_menu
    menu.get_node("Button").pressed.connect(_on_pickup)
    menu.get_node("Button2").pressed.connect(_on_destroy)


func _populate_menu(menu: Control):
    var label: Label = menu.get_node("Label")
    label.text = "%s\n%s" % [item.name, item.description]

    var pickup_button: Button = menu.get_node("Button")
    pickup_button.text = "'Enter' Pick up"

    var destroy_button: Button = menu.get_node("Button2")
    destroy_button.text = "'Esc' Destroy"

func default_action():
    _on_pickup()

func cancel_action():
    _on_destroy()

func _on_pickup():
    var tower = get_tree().current_scene.get_node_or_null("Tower")
    if tower:
        var holder = tower.get_node_or_null("ItemHolder")
        if holder:
            holder.add_item(item)
    queue_free()

func _on_destroy():
    queue_free()
