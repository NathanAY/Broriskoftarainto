extends CanvasLayer
class_name ShopMenu

@onready var next_stage_button: Button = $Control/VBoxContainer/BottomContainer/ButtonsContainer/NextStageButton
@onready var reroll_button: Button = $Control/VBoxContainer/BottomContainer/ButtonsContainer/RerollButton
@onready var money_label: Label = $Control/VBoxContainer/TopHBoxContainer/Money
@onready var items_container: HBoxContainer = $Control/VBoxContainer/MidContainer/ShopArea/ItemsList
@onready var stats_container: VBoxContainer = $Control/VBoxContainer/MidContainer/StatsPanel/StatsScroll/StatsList
@onready var collected_items_container: GridContainer = $Control/VBoxContainer/BottomContainer/ItemsContainer/ItemsScroll/ItemsMargin/List
@onready var weapons_container: GridContainer = $Control/VBoxContainer/BottomContainer/WeaponsContainer/WeaponsScroll/WeaponsMargin/List
@onready var tooltip: TooltipUi = $Tooltip
@onready var price_analyzer: ItemPriceAnalyzer = $PriceAnalyzer

signal next_stage_pressed

const SHOP_ITEM_CARD_SCENE: PackedScene = preload("res://src/Scenes/menu/ShopItemCard.tscn")

## The Collected Items / Weapons lists are the same tile the character menu's
## grids use, at the same compact scale: one gear card, one visual language.
const ICON_CARD_SCENE: PackedScene = preload("res://src/ui/IconCard.tscn")

const WEAPON_CHANCE: float = 0.1

## Number of slots in the shop row. The row always occupies this many slots:
## an empty placeholder is shown for every slot without an offer, so cards
## never resize when an offer is bought.
const SHOP_SLOT_COUNT: int = 4

## Placeholder geometry. Must match `ShopItemCard`'s `custom_minimum_size`
## so an empty slot is exactly the width of a filled one.
const EMPTY_SLOT_SIZE: Vector2 = Vector2(220, 340)
const EMPTY_SLOT_META: String = "empty_slot"

var staged_items: Array = []
var locked_items: Array = []   # items that persist between shops
var character: Character = null
@export var item_factory: ItemFactory = null
var phase: int = 1  # 1 = collected pickups, 2 = generated shop items
var value_labels: Dictionary = {}  # stat_name -> Label

func _ready():
    visible = false
    next_stage_button.visible = false
    reroll_button.visible = false
    next_stage_button.pressed.connect(_on_next_stage_pressed)
    reroll_button.pressed.connect(_on_reroll_pressed)

func show_menu():
    character = GlobalGameState.current_character
    get_tree().paused = true
    visible = true
    next_stage_button.visible = false
    reroll_button.visible = false
    phase = 1
    _update_money_label()
    _update_stats() # Update stats when opening the shop
    _update_character_info() # Update items and weapons
    _refresh_affordability()

func _update_character_info() -> void:
    if not character: return

    var item_holder: ItemHolder = character.get_node_or_null("ItemHolder")
    if item_holder:
        _fill_gear_cards(collected_items_container, item_holder.items)

    var weapon_holder = character.get_node_or_null("WeaponHolder")
    if weapon_holder:
        _fill_gear_cards(weapons_container, weapon_holder.weapons)


## One `IconCard` per resource, each wired to the shared tooltip. The character
## menu fills its two grids the same way, so a tile cannot look different in the
## shop from the one the player just saw in the pause menu.
func _fill_gear_cards(container: GridContainer, resources: Array) -> void:
    for child in container.get_children():
        child.queue_free()
    for resource in resources:
        var card: IconCard = ICON_CARD_SCENE.instantiate()
        # Scaled before the tree so the first layout is already the compact one.
        card.apply_scale(IconCard.COMPACT_SCALE)
        container.add_child(card)
        card.set_display(resource)
        tooltip.bind_to_row(card, resource)

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
    # Pad the row only if we are staying in phase 1: `_start_shop_phase()`
    # already lays out its own row, and padding first would queue placeholders
    # that are immediately thrown away.
    if not _check_phase_progression():
        _sync_empty_slots()

# ------------------- SHOP ROW SLOTS -------------------

## Builds a dim, inert placeholder that occupies one shop slot. Intentionally
## empty -- a card-sized blank panel, no text.
func _make_empty_slot() -> PanelContainer:
    var slot := PanelContainer.new()
    slot.custom_minimum_size = EMPTY_SLOT_SIZE
    slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
    slot.set_meta(EMPTY_SLOT_META, true)

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.09, 0.098, 0.125, 0.55)
    style.border_color = Color(0.19, 0.207, 0.254, 1)
    style.set_border_width_all(2)
    style.set_corner_radius_all(8)
    slot.add_theme_stylebox_override("panel", style)
    return slot


func _is_empty_slot(node: Node) -> bool:
    return node.has_meta(EMPTY_SLOT_META)


func _empty_slot_count() -> int:
    var cnt := 0
    for child in items_container.get_children():
        if not child.is_queued_for_deletion() and _is_empty_slot(child):
            cnt += 1
    return cnt


## Inserts a placeholder at a specific slot position. Used when an offer is
## bought so the blank slot takes the place of the card that left, instead of
## everything to its right shifting left.
func _insert_empty_slot_at(index: int) -> void:
    var slot := _make_empty_slot()
    items_container.add_child(slot)
    items_container.move_child(slot, clampi(index, 0, items_container.get_child_count()))


## Pads the row out to SHOP_SLOT_COUNT. Purely additive and idempotent: it
## never moves or removes an existing slot, so positions set by
## `_insert_empty_slot_at()` survive. Callers that reset the whole row free
## every child first.
func _sync_empty_slots() -> void:
    var missing: int = SHOP_SLOT_COUNT - _active_item_count() - _empty_slot_count()
    for i in range(maxi(missing, 0)):
        _insert_empty_slot_at(items_container.get_child_count())


## Fades a card out without it occupying a slot: the card is moved out of the
## layout (keeping its on-screen rect) so the row never briefly holds an extra
## child and the cards to its right do not shift during the fade.
##
## The row then re-packs itself, differently per phase:
## - Phase 1 (pickups) compacts left, so the remaining pickups slide into the
##   gap instead of leaving a hole the player has to scroll past.
## - Phase 2 (shop) keeps slot positions, so the blank marks the offer that was
##   bought and the offers to its right do not jump around.
func _resolve_card(card: ShopItemCard) -> void:
    var index: int = card.get_index()
    var rect: Rect2 = card.get_global_rect()
    card.reparent(self)
    card.global_position = rect.position
    card.size = rect.size
    card.fade_out_and_free()
    if phase == 2:
        _insert_empty_slot_at(index)
    else:
        _sync_empty_slots()


# ------------------- PHASE 1 (collected pickups) -------------------
func _add_item_entry(item: Item):
    var card: ShopItemCard = SHOP_ITEM_CARD_SCENE.instantiate()
    card.set_meta("item", item)
    items_container.add_child(card)
    card.set_item_display(item)
    card.primary_button.text = "Take"
    var sell_price: int = price_analyzer.get_sell_price(item)
    card.secondary_button.text = "Sell (+%d)" % sell_price
    card.set_price(sell_price)
    card.set_affordable(true)  # pickups are free to take
    card.primary_button.pressed.connect(func():
        var holder: ItemHolder = character.get_node_or_null("ItemHolder")
        if holder:
            holder.add_item(item)
        _resolve_card(card)
        _update_stats() # Update stats after taking item
        _update_character_info()
        _check_phase_progression()
    )
    card.secondary_button.pressed.connect(func():
        character.stats.set_base_stat("money", character.stats.stats.get("money", 0) + price_analyzer.get_sell_price(item))
        _resolve_card(card)
        _update_money_label()
        _update_stats() # Update stats after selling
        _refresh_affordability()
        _check_phase_progression()
    )

# ------------------- PHASE 2 (shop) -------------------
func _add_shop_item_entry(offer: Resource, existing_id: String = ""):
    var card: ShopItemCard = SHOP_ITEM_CARD_SCENE.instantiate()
    var entry_id = existing_id if existing_id != "" else _generate_entry_id()
    card.set_meta("item", offer)
    card.set_meta("id", entry_id)
    items_container.add_child(card)
    card.set_item_display(offer)

    # Buy button
    var price: int = price_analyzer.get_price(offer)
    card.primary_button.text = "Buy (%d)" % price
    card.set_price(price)
    card.set_affordable(_current_money() >= price)
    card.primary_button.pressed.connect(func():
        var money = _current_money()
        if money >= price:
            character.stats.set_base_stat("money", money - price)
            if offer is BaseWeapon:
                var weapon_holder: WeaponHolder = character.get_node_or_null("WeaponHolder")
                if weapon_holder:
                    weapon_holder.add_weapon(offer as BaseWeapon)
            else:
                var holder: ItemHolder = character.get_node_or_null("ItemHolder")
                if holder:
                    holder.add_item(offer as Item)
            _resolve_card(card)
            # remove this exact entry from locked list if it was there
            locked_items = locked_items.filter(func(li): return li.id != entry_id)
            _update_money_label()
            _update_stats() # Update stats after buying
            _update_character_info()
            _refresh_affordability()
    )

    # Lock/Unlock button
    var is_locked = locked_items.any(func(li): return li.id == entry_id)
    card.secondary_button.text = "Unlock" if is_locked else "Lock"
    card.set_locked(is_locked)
    card.secondary_button.pressed.connect(func():
        if locked_items.any(func(li): return li.id == entry_id):
            locked_items = locked_items.filter(func(li): return li.id != entry_id)
            card.secondary_button.text = "Lock"
            card.set_locked(false)
        else:
            locked_items.append({"id": entry_id, "item": offer})
            card.secondary_button.text = "Unlock"
            card.set_locked(true)
    )


## Re-applies the affordable state to every card in the row. Called after any
## transaction that changes the player's money.
func _refresh_affordability() -> void:
    var money := _current_money()
    for child in items_container.get_children():
        # Pickup-phase cards have no entry id and are always free to take.
        if not child.has_meta("id"):
            continue
        var card := child as ShopItemCard
        if card:
            card.set_money(money)
            card.set_affordable(money >= card.price)


func _current_money() -> float:
    if character == null or not character.has_node("Stats"):
        return 0.0
    return float(character.get_node("Stats").stats.get("money", 0))


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

        tooltip.bind_to_row_text(hbox, ItemTooltip.stat_hint(stat_name), icon_texture)

        stats_container.add_child(hbox)
        value_labels[stat_name] = value_label

## Advances to the shop phase when the pickup row is empty.
## Returns true if the shop phase was started.
func _check_phase_progression() -> bool:
    # use active count (exclude queued-for-deletion nodes)
    if _active_item_count() == 0 and phase == 1:
        _start_shop_phase()
        return true
    return false

# helper: count offers that occupy a slot (excludes placeholders and cards
# that are on their way out).
func _active_item_count() -> int:
    var cnt := 0
    for child in items_container.get_children():
        if child.is_queued_for_deletion():
            continue
        if _is_empty_slot(child):
            continue
        # A card taken/sold/bought is still alive while its fade-out tween
        # runs, so it must not keep the shop stuck in phase 1.
        var card := child as ShopItemCard
        if card and card.is_resolving():
            continue
        cnt += 1
    return cnt

func _start_shop_phase():
    phase = 2
    next_stage_button.visible = true
    reroll_button.visible = true
    # clear visuals (deferred)
    for child in items_container.get_children():
        child.queue_free()

    if not item_factory:
        push_warning("ShopMenu: No item_factory assigned!")
        _sync_empty_slots()
        return

    # show locked items first (cap to the row width to avoid overflow)
    var locked_to_show = min(locked_items.size(), SHOP_SLOT_COUNT)
    for i in range(locked_to_show):
        _add_shop_item_entry(locked_items[i].get("item"), locked_items[i].get("id", ""))

    # fill the remaining slots
    _refill_shop_items()


## Tops the row back up to SHOP_SLOT_COUNT offers. Only used when the shop
## starts or the player rerolls -- buying leaves the slot empty on purpose.
func _refill_shop_items():
    while _active_item_count() < SHOP_SLOT_COUNT:
        var new_offer: Resource = _generate_shop_offer()
        if not new_offer:
            break
        _add_shop_item_entry(new_offer)
    _sync_empty_slots()

# 10% weapon chance, otherwise a generated item.
func _generate_shop_offer() -> Resource:
    if not item_factory:
        return null
    if item_factory.rng.randf() < WEAPON_CHANCE:
        var weapon: BaseWeapon = item_factory.get_random_weapon()
        if weapon:
            return weapon
    return item_factory.get_item_from_pool_or_generate()

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
        if not child.has_meta("id"):
            child.queue_free()
            continue
        var entry_id: String = child.get_meta("id")
        var is_locked = locked_items.any(func(li): return li.id == entry_id)
        if not is_locked:
            child.queue_free()

    _refill_shop_items()
    _update_money_label()
    _update_stats() # Update stats after reroll
