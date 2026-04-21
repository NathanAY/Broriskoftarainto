extends CanvasLayer
class_name ShopMenu

@onready var next_stage_button: Button = $Control/VBoxContainer/BottomContainer/ButtonsContainer/NextStageButton
@onready var reroll_button: Button = $Control/VBoxContainer/BottomContainer/ButtonsContainer/RerollButton
@onready var money_label: Label = $Control/VBoxContainer/TopHBoxContainer/Money
@onready var items_container: VBoxContainer = $Control/VBoxContainer/MidContainer/ShopArea/ItemsList
@onready var stats_container: VBoxContainer = $Control/VBoxContainer/MidContainer/StatsPanel/StatsScroll/StatsList
@onready var collected_items_container: VBoxContainer = $Control/VBoxContainer/BottomContainer/ItemsContainer/ItemsScroll/List
@onready var weapons_container: GridContainer = $Control/VBoxContainer/BottomContainer/WeaponsContainer/WeaponsScroll/List

signal next_stage_pressed

var staged_items: Array = []
var locked_items: Array = []   # items that persist between shops
var character: Character = null
@export var item_factory: ItemFactory = null
var phase: int = 1  # 1 = collected pickups, 2 = generated shop items
var value_labels: Dictionary = {}  # stat_name -> Label

func _ready():
    visible = false
    reroll_button.visible = false
    next_stage_button.pressed.connect(_on_next_stage_pressed)
    reroll_button.pressed.connect(_on_reroll_pressed)

func show_menu():
    character = GlobalGameState.current_character
    get_tree().paused = true
    visible = true
    reroll_button.visible = false
    phase = 1
    _update_money_label()
    _update_stats() # Update stats when opening the shop
    _update_character_info() # Update items and weapons

func _update_character_info() -> void:
    if not character: return

    # Update Items
    var item_holder = character.get_node_or_null("ItemHolder")
    if item_holder:
        for child in collected_items_container.get_children():
            child.queue_free()
        for item in item_holder.items:
            var l = Label.new()
            l.text = item.name
            collected_items_container.add_child(l)

    # Update Weapons
    var weapon_holder = character.get_node_or_null("WeaponHolder")
    if weapon_holder:
        for child in weapons_container.get_children():
            child.queue_free()
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

func hide_menu():
    get_tree().paused = false
    visible = false

func _on_next_stage_pressed():
    hide_menu()
    staged_items.clear()
    emit_signal("next_stage_pressed")

func load_items(items: Array):
    staged_items = items
    for child in items_container.get_children():
        child.queue_free()
    for item in items:
        _add_item_entry(item)
    _update_money_label()
    _update_stats() # Update stats when loading items
    _check_phase_progression()

# ------------------- PHASE 1 (collected pickups) -------------------
func _add_item_entry(item: Item):
    var hbox = HBoxContainer.new()

    # Take button
    var btn_take = Button.new()
    btn_take.text = "Take"
    btn_take.pressed.connect(func():
        var holder: ItemHolder = character.get_node_or_null("ItemHolder")
        if holder:
            holder.add_item(item)
        hbox.queue_free()
        _update_stats() # Update stats after taking item
        _update_character_info()
        _check_phase_progression()
    )
    hbox.add_child(btn_take)

    # Sell button
    var btn_sell = Button.new()
    btn_sell.text = "Sell"
    btn_sell.pressed.connect(func():
        character.stats.set_base_stat("money", character.stats.stats.get("money", 0) + 1)
        hbox.queue_free()
        _update_money_label()
        _update_stats() # Update stats after selling
        _check_phase_progression()
    )
    hbox.add_child(btn_sell)

    # Label
    var label = Label.new()
    label.text = "%s - %s" % [item.name, item.description]
    hbox.add_child(label)

    items_container.add_child(hbox)

# ------------------- PHASE 2 (shop) -------------------
func _add_shop_item_entry(item: Item):
    var hbox = HBoxContainer.new()
    var entry_id = _generate_entry_id()
    hbox.set_meta("item", item)
    hbox.set_meta("id", entry_id)

    # Buy button
    var btn_buy = Button.new()
    btn_buy.text = "Buy"
    btn_buy.pressed.connect(func():
        var money = character.stats.stats.get("money", 0)
        if money >= 1:
            character.stats.set_base_stat("money", money - 1)
            var holder: ItemHolder = character.get_node_or_null("ItemHolder")
            if holder:
                holder.add_item(item)
            hbox.queue_free()
            # remove this exact entry from locked list if it was there
            locked_items = locked_items.filter(func(li): return li.id != entry_id)
            _update_money_label()
            _update_stats() # Update stats after buying
            _update_character_info()
    )
    hbox.add_child(btn_buy)

    # Lock/Unlock button
    var btn_lock = Button.new()
    var is_locked = locked_items.any(func(li): return li.id == entry_id)
    btn_lock.text = "Unlock" if is_locked else "Lock"
    btn_lock.pressed.connect(func():
        if locked_items.any(func(li): return li.id == entry_id):
            locked_items = locked_items.filter(func(li): return li.id != entry_id)
            btn_lock.text = "Lock"
        else:
            locked_items.append({"id": entry_id, "item": item})
            btn_lock.text = "Unlock"
    )
    hbox.add_child(btn_lock)

    # Label
    var label = Label.new()
    label.text = "%s - %s" % [item.name, item.description]
    hbox.add_child(label)

    items_container.add_child(hbox)


# ------------------- Shared -------------------
func _update_money_label():
    if character and character.has_node("Stats"):
        var stats = character.get_node("Stats")
        var money = stats.stats.get("money", 0)
        money_label.text = "Money: %d" % money
    else:
        money_label.text = "Money: 0"

# --- stats UI ---------------------------------------------------------------

func _update_stats() -> void:
    for child in stats_container.get_children():
        child.queue_free()
    value_labels.clear()

    if not character or not character.has_node("Stats"):
        return

    var stats_node: Stats = character.get_node("Stats")
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

func _check_phase_progression():
    # use active count (exclude queued-for-deletion nodes)
    if _active_item_count() == 0 and phase == 1:
        _start_shop_phase()

# helper: count active (not queued) children
func _active_item_count() -> int:
    var cnt := 0
    for child in items_container.get_children():
        if not child.is_queued_for_deletion():
            cnt += 1
    return cnt

func _start_shop_phase():
    phase = 2
    reroll_button.visible = true
    # clear visuals (deferred)
    for child in items_container.get_children():
        child.queue_free()

    if not item_factory:
        push_warning("ShopMenu: No item_factory assigned!")
        return

    # show locked items first (cap to 4 to avoid overflow)
    var locked_to_show = min(locked_items.size(), 4)
    for i in range(locked_to_show):
        _add_shop_item_entry(locked_items[i].get("item"))

    # fill up to 4 active items
    while _active_item_count() < 4:
        var new_item: Item = item_factory.get_item_from_pool_or_generate()
        if not new_item:
            break
        _add_shop_item_entry(new_item)

# ensure shop stays at 4 items after buys/locks
func _refill_shop_items():
    while _active_item_count() < 4:
        var new_item: Item = item_factory.get_item_from_pool_or_generate()
        if not new_item:
            break
        _add_shop_item_entry(new_item)

# ----- REROLL -----
var _shop_entry_id_counter: int = 0

func _generate_entry_id() -> String:
    _shop_entry_id_counter += 1
    return str(Time.get_unix_time_from_system()) + "_" + str(_shop_entry_id_counter)

func _on_reroll_pressed():
    if phase != 2:
        return
    var money = character.stats.stats.get("money", 0)
    if money < 1:
        return
    character.stats.set_base_stat("money", money - 1)

    # remove all non-locked items by comparing IDs
    for child in items_container.get_children():
        var entry_id: String = child.get_meta("id")
        var is_locked = locked_items.any(func(li): return li.id == entry_id)
        if not is_locked:
            child.queue_free()

    _refill_shop_items()
    _update_money_label()
    _update_stats() # Update stats after reroll
