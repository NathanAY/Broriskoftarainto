# CharacterUI.gd
extends Control

@onready var items_container: VBoxContainer = $VBoxContainer/WeaponsAndItemsContainer/LeftContainer/LeftHBox/ItemsScroll/ItemsList
@onready var stats_container: VBoxContainer = $VBoxContainer/WeaponsAndItemsContainer/StatsContainer/StatsHBox/StatsScroll/StatsList
@onready var weapons_container: GridContainer = $VBoxContainer/WeaponsAndItemsContainer/LeftContainer/LeftHBox/WeaponsScroll/WeaponsList
@onready var back_button: Button = $VBoxContainer/Footer/Close

var character: Character
var stats_node: Stats = null
var item_holder: ItemHolder = null
var weapon_holder: WeaponHolder = null
var value_labels: Dictionary = {}  # stat_name -> Label


func _ready():
    character = GlobalGameState.current_character
    if not character:
        push_error("CharacterUI: No character assigned! Set the 'character' export or call set_character(character).")
        return

    back_button.pressed.connect(_on_back_pressed)
    stats_node = character.get_node_or_null("Stats")
    item_holder = character.get_node_or_null("ItemHolder")
    weapon_holder = character.get_node_or_null("WeaponHolder")
    var em: EventManager = character.get_node_or_null("EventManager")

    # Setup stats UI and listeners
    if stats_node:
        _update_stats()
        if stats_node.has_signal("stat_changed"):
            stats_node.connect("stat_changed", Callable(self, "_on_stat_changed"))
        # also subscribe to character event manager if present (emits on_stat_changes)
        if em:
            em.subscribe("on_stat_changes", Callable(self, "_on_stat_changed_event"))

    # Setup items UI and listeners
    if item_holder:
        _update_items()
        if em:
            em.subscribe("on_item_added", Callable(self, "_on_item_added"))
            em.subscribe("on_item_removed", Callable(self, "_on_item_removed"))
    if weapon_holder:
        _update_weapons()
        em.subscribe("on_weapon_changes", Callable(self, "_on_weapon_changed"))


# --- utilities ---------------------------------------------------------------

func _clear_container(container: Node) -> void:
    # safe way to remove all children
    for child in container.get_children():
        child.queue_free()

# --- stats UI ---------------------------------------------------------------

func _update_stats() -> void:
    _clear_container(stats_container)
    value_labels.clear()
    if not stats_node:
        return

    # iterate over base stat keys (Stats.gd stores a `stats` dict)
    if not stats_node.stats:
        return

    for stat_name in stats_node.stats.keys():
        var hbox = HBoxContainer.new()

        # Add Icon
        var icon_texture: Texture2D = Stats.get_stat_icon(stat_name)
        var icon_rect = TextureRect.new()
        icon_rect.texture = icon_texture
        icon_rect.custom_minimum_size = Vector2(24, 24)
        icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        hbox.add_child(icon_rect)

        # Add Value Label
        var value_label = Label.new()
        var name_label = str(stat_name).capitalize()

        var val = stats_node.get_stat(stat_name)
        value_label.text = "%s: %.2f" % [name_label, val]
        value_label.name = "value_" + str(stat_name)
        hbox.add_child(value_label)

        stats_container.add_child(hbox)

        value_labels[stat_name] = value_label


# Called when Stats emits its signal (stat_changed(stat_name, new_value))
func _on_stat_changed(event) -> void:
    var stat_name: String = event["stat_name"]
    var new_value: float = event["final_value"]
    var lbl = value_labels.get(stat_name, null)
    if lbl:
        lbl.text = "%s: %.2f" % [str(stat_name).capitalize(), new_value]
    else:
        # new stat not present in UI — rebuild full list
        _update_stats()

# Called when EventManager emits on_stat_changes(stat_name, value)
# LocalEventManager.callv passes positional args, so this function signature matches
func _on_stat_changed_event(event) -> void:
    _on_stat_changed(event)

# --- weapon UI ---------------------------------------------------------------

func _update_weapons() -> void:
    _clear_container(weapons_container)
    if not weapon_holder or not weapon_holder.weapons:
        return

    for weapon in weapon_holder.weapons:
        var vbox = VBoxContainer.new()

        # Add Icon
        var icon_rect = TextureRect.new()
        icon_rect.custom_minimum_size = Vector2(48, 48)
        icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

        if weapon.get("sprite"):
            icon_rect.texture = weapon.sprite
        else:
            icon_rect.texture = load("res://Assets/weapons/_default.png")

        vbox.add_child(icon_rect)

        # Add Name
        var name_label = Label.new()
        name_label.text = weapon.name
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vbox.add_child(name_label)

        weapons_container.add_child(vbox)
# Called when weapons emits its signal (weapon_changed(weapon_name, new_value))
func _on_weapon_changed(event) -> void:
    print("Character_ui, _on_weapon_changed", event)
    _update_weapons()


# --- items UI ---------------------------------------------------------------

func _update_items() -> void:
    _clear_container(items_container)
    if not item_holder:
        return

    if not item_holder.items:
        return

    for item in item_holder.items:
        var l = Label.new()
        l.text = _item_display_name(item)
        items_container.add_child(l)

func _on_item_added(event: Dictionary) -> void:
    var entity = event.get("hold_owner")
    var item = event.get("item")
    # entity is the owner of the item; only update UI if it's the current character
    if entity != character:
        return
    var l = Label.new()
    l.text = _item_display_name(item)
    items_container.add_child(l)
    #_update_items()

func _on_item_removed(event: Dictionary) -> void:
    var entity = event.get("hold_owner")
    var item = event.get("item")
    if entity != character:
        return  
    _update_items()

func _item_display_name(item: Resource) -> String:
    # Prefer Item.name, fallback to resource_name or to_class string
    if typeof(item) == TYPE_OBJECT and item is Item:
        return str(item.name)
    if "resource_name" in item:
        return str(item.resource_name)
    return str(item)

func _on_back_pressed():
    visible = false
    get_parent().get_node("Control").visible = true
