extends Interactable
class_name ShopPortal

@export var label_text: String = "Go to Shop"

func _populate_menu(menu: Control):
    var label: Label = menu.get_node("Label")
    label.text = "🛒 %s" % label_text

    var go_button: Button = menu.get_node("Button")
    go_button.text = "'Enter' Go to Shop"

    var cancel_button: Button = menu.get_node("Button2")
    cancel_button.text = "'Tab' Leave"

func default_action():
    var shop: ShopMenu = get_tree().current_scene.get_node_or_null("UI/ShopMenu")
    if shop:
        var character = get_tree().current_scene.get_node_or_null("Character")
        shop.character = character
        _clean_game_area()
        shop.show_menu()
    queue_free()  # remove portal after entering shop

func _clean_game_area():
    # cleanup stage-specific nodes (death marks, altars etc.)
    var death_marks_parent = get_tree().current_scene.get_node_or_null("Nodes/death_marks")
    for child in death_marks_parent.get_children():
        child.queue_free()
    var altars = get_tree().current_scene.get_node_or_null("Nodes/altars")
    for child in altars.get_children():
        child.queue_free()
    # collect pickups
    var pickups = get_tree().current_scene.get_node_or_null("Nodes/pickups")
    if pickups:
        var items: Array = []
        for child in pickups.get_children():
            items.append(child.item)
            child.queue_free()

        var menu: ShopMenu = get_tree().current_scene.get_node_or_null("UI/ShopMenu")
        if menu:
            menu.load_items(items)

func cancel_action():
    # Player just leaves without going to shop
    pass
