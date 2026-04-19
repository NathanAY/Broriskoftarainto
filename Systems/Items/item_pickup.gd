# ItemPickup.gd
extends Interactable

@export var item: Item

func _ready():
    super._ready()
    var menu = interaction_menu
    menu.get_node("Button").pressed.connect(_on_pickup)
    menu.get_node("Button2").pressed.connect(_on_destroy)

func _populate_menu(menu: Control):
    var label: Label = menu.get_node_or_null("Description/Label")
    if label:
        label.text = "%s\n%s" % [item.name, item.description]

    # Add Stats modifiers if they exist
    if item.modifiers and not item.modifiers.is_empty():
        add_stats_descriptions(menu)
        
    var pickup_button: Button = menu.get_node("Button")
    pickup_button.text = "'Enter' Pick up"

    var destroy_button: Button = menu.get_node("Button2")
    destroy_button.text = "'Tab' Destroy"

func add_stats_descriptions(menu: Control):
    var description_container: VBoxContainer = menu.get_node("Description")
        # Clear previous stats
    for child in description_container.get_children():
        child.queue_free()

    for stat_name in item.modifiers:
        var hbox = HBoxContainer.new()

        # Icon
        var icon_rect = TextureRect.new()
        icon_rect.custom_minimum_size = Vector2(24, 24)
        icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

        icon_rect.texture = Stats.get_stat_icon(stat_name)
        hbox.add_child(icon_rect)

        # Label
        var val_label = Label.new()
        var mod_info = item.modifiers[stat_name]
        # Assuming flat values for now as per your Item.gd example
        var display_val = ""
        if mod_info is Dictionary:
            display_val = str(mod_info.values()[0]) # Simplified display
        else:
            display_val = str(mod_info)

        val_label.text = "%s: %s" % [stat_name.capitalize(), display_val]
        hbox.add_child(val_label)

        description_container.add_child(hbox)
    

func default_action():
    _on_pickup()

func cancel_action():
    _on_destroy()

func _on_pickup():
    var character = get_tree().current_scene.get_node_or_null("Character")
    if character:
        var holder = character.get_node_or_null("ItemHolder")
        if holder:
            holder.add_item(item)
    queue_free()

func _on_destroy():
    queue_free()
