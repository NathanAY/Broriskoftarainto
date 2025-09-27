extends Interactable
class_name ItemSacrificeAltar

@export var altar_item: Item
var sacrifice_cost: int = 1
var sacrifice_count: int = 0

func add_item(item: Item):
    altar_item = item
    _update_menu_text()

func _populate_menu(menu: Control):
    var label: Label = menu.get_node("Label")
    label.text = "🪔 Sacrifice Altar\nOffering required: %d item(s)\n\nReward:\n%s\n%s" % [
            sacrifice_cost,
            altar_item.name,
            altar_item.description
        ]

    var sacrifice_button: Button = menu.get_node("Button")
    sacrifice_button.text = "'Enter' Sacrifice"

    var cancel_button: Button = menu.get_node("Button2")
    cancel_button.text = "'Tab' Leave"

func _update_menu_text():
    if interaction_menu:
        _populate_menu(interaction_menu)

func default_action():
    var tower = get_tree().current_scene.get_node_or_null("Tower")
    if not tower:
        return
    var holder: ItemHolder = tower.get_node_or_null("ItemHolder")
    if not holder:
        return
    if holder.items.size() < sacrifice_cost:
        push_warning("Not enough items to sacrifice!")
        return
    for i in range(sacrifice_cost):
        var random_item = holder.items.pick_random()
        holder.remove_item(random_item)
    holder.add_item(altar_item)
    sacrifice_count += 1
    sacrifice_cost = sacrifice_count + 1

func cancel_action():
    queue_free()
