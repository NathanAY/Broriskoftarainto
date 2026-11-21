extends Portal
class_name ShopPortal

@export var label_text: String = "Go to Shop"

## Seconds by which pickups' launches are spread, so they do not arrive as one.
const PICKUP_STAGGER := 0.2

func _populate_menu(menu: Control):
    var label: Label = menu.get_node("Description/Label")
    label.text = "🛒 %s" % label_text

    var go_button: Button = menu.get_node("Button")
    go_button.text = "'Enter' Go to Shop"

    var cancel_button: Button = menu.get_node("Button2")
    cancel_button.text = "'Tab' Leave"

## Every pickup on the ground flies into the portal with the player, so it reads
## as carried to the shop, where it reappears as a Take / Sell card.
func _on_entry_started() -> void:
    var pickups = get_tree().current_scene.get_node_or_null("Nodes/pickups")
    if pickups == null:
        return
    var tint := aura.color if aura else Color.WHITE
    for pickup in pickups.get_children():
        if _is_item_pickup(pickup):
            _fly_in(pickup, tint)

## `Nodes/pickups` also holds heal drops, which carry no `item` and cannot be
## taken or sold, so only item pickups travel to the shop.
static func _is_item_pickup(node: Node) -> bool:
    return node is Node2D and "item" in node and node.item != null

func _fly_in(pickup: Node2D, tint: Color) -> void:
    if pickup is Interactable:
        pickup.disable_interaction()
    pickup.add_child(PortalAura.make_trail(tint))
    var delay := randf() * PICKUP_STAGGER
    var flight := ENTRY_DURATION - delay
    var tween := create_tween()
    tween.tween_interval(delay)
    tween.tween_property(pickup, "global_position", global_position, flight) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.parallel().tween_property(pickup, "scale", pickup.scale * 0.3, flight) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.parallel().tween_property(pickup, "rotation", pickup.rotation + TAU * 2.0, flight)
    tween.tween_callback(pickup.hide)

func _on_entered() -> void:
    var shop: ShopMenu = get_tree().current_scene.get_node_or_null("UI/ShopMenu")
    if shop:
        shop.character = get_tree().current_scene.get_node_or_null("Character")
        # Show the menu FIRST: show_menu() resets the menu to phase 1, so the
        # pickup harvest (which can complete phase 1 immediately) must run after.
        shop.show_menu()
        _clean_game_area(shop)
    queue_free()  # remove portal after entering shop

func _clean_game_area(shop: ShopMenu):
    # cleanup stage-specific nodes (death marks, altars etc.)
    var death_marks_parent = get_tree().current_scene.get_node_or_null("Nodes/death_marks")
    if death_marks_parent:
        for child in death_marks_parent.get_children():
            child.queue_free()
    var altars = get_tree().current_scene.get_node_or_null("Nodes/altars")
    if altars:
        for child in altars.get_children():
            child.queue_free()
    # collect item pickups; anything else left there (heal drops) is cleared
    var pickups = get_tree().current_scene.get_node_or_null("Nodes/pickups")
    if pickups:
        var items: Array = []
        for child in pickups.get_children():
            if _is_item_pickup(child):
                items.append(child.item)
            child.queue_free()

        if shop:
            shop.load_items(items)

func cancel_action():
    # Player just leaves without going to shop
    pass
