# GdUnit TestSuite for the prepared ShopItemCard scene.
class_name ShopItemCardTest
extends GdUnitTestSuite

const SHOP_SCENE := "res://src/Scenes/menu/ShopMenu.tscn"
const CARD_SCENE := "res://src/Scenes/menu/ShopItemCard.tscn"
const PLUS_DAMAGE_ITEM := "res://src/Resources/items/PlusDamageItem.tres"


func _build_character() -> Character:
    var character := Character.new()
    character.name = "Character"
    var event_manager := EventManager.new()
    event_manager.name = "EventManager"
    character.add_child(event_manager)
    var stats := Stats.new()
    stats.name = "Stats"
    stats.event_manager = event_manager
    character.add_child(stats)
    var item_holder := ItemHolder.new()
    item_holder.name = "ItemHolder"
    character.add_child(item_holder)
    var weapon_holder := WeaponHolder.new()
    weapon_holder.name = "WeaponHolder"
    character.add_child(weapon_holder)
    return character


func test_card_has_icon_above_tooltip_text() -> void:
    var card: ShopItemCard = load(CARD_SCENE).instantiate()
    add_child(card)
    var item: Item = load(PLUS_DAMAGE_ITEM)
    card.set_item_display(item)

    # Rectangle card with icon holder, scrollable text and side-by-side buttons.
    assert_that(card).is_not_null()
    assert_bool(card.custom_minimum_size.x >= 150.0).is_true()
    assert_that(card.get_node("Margin/VBox/Header/IconPlate/IconHolder")).is_not_null()
    assert_that(card.get_node("Margin/VBox/InfoScroll")).is_not_null()
    assert_that(card.get_node("Margin/VBox/InfoScroll/InfoLabel")).is_not_null()

    var vbox: VBoxContainer = card.get_node("Margin/VBox")
    assert_int(vbox.get_node("Header").get_index()).is_less(vbox.get_node("InfoScroll").get_index())
    assert_int(vbox.get_node("InfoScroll").get_index()).is_less(vbox.get_node("Buttons").get_index())

    # Body text is built from the structured card_rows() builder.
    assert_str(card.info_label.text).is_equal(ItemDisplayPanel.build_bbcode(ItemTooltip.card_rows(item), item))

    # Icon is placed at the top of the card.
    assert_int(card.icon_holder.get_child_count()).is_equal(1)

    # Buttons sit side-by-side in an HBox.
    var buttons: HBoxContainer = card.get_node("Margin/VBox/Buttons")
    assert_that(buttons).is_not_null()
    assert_that(buttons is HBoxContainer).is_true()
    assert_str(card.primary_button.text).is_not_empty()
    assert_str(card.secondary_button.text).is_not_empty()

    card.free()


func test_shop_items_are_horizontal_cards() -> void:
    var shop = load(SHOP_SCENE).instantiate()
    add_child(shop)

    # Items container is a horizontal row.
    assert_that(shop.items_container is HBoxContainer).is_true()

    shop.character = _build_character()

    var item: Item = load(PLUS_DAMAGE_ITEM)
    shop._add_shop_item_entry(item)
    shop._add_item_entry(item)

    assert_int(shop.items_container.get_child_count()).is_equal(2)
    for child in shop.items_container.get_children():
        assert_that(child is ShopItemCard).is_true()

    var shop_card: ShopItemCard = shop.items_container.get_child(0)
    assert_str(shop_card.primary_button.text).is_equal("Buy (1)")
    assert_str(shop_card.secondary_button.text).is_equal("Lock")
    assert_str(shop_card.name_label.text).is_equal(item.name)
    assert_int(shop_card.price).is_equal(1)
    assert_int(shop_card.icon_holder.get_child_count()).is_equal(1)

    var pickup_card: ShopItemCard = shop.items_container.get_child(1)
    assert_str(pickup_card.primary_button.text).is_equal("Take")
    assert_str(pickup_card.secondary_button.text).is_equal("Sell (+1)")
    assert_str(pickup_card.name_label.text).is_equal(item.name)

    shop.character.free()
    shop.free()


func test_collected_items_and_weapons_use_the_character_menu_card() -> void:
    var shop = load(SHOP_SCENE).instantiate()
    add_child(shop)
    var character := _build_character()
    shop.character = character

    var items: Array[Item] = [
        load("res://src/Resources/items/ArmorPlate.tres"),
        load("res://src/Resources/items/CritGlass.tres"),
        load("res://src/Resources/items/Knockback.tres"),
        load("res://src/Resources/items/PlusDamageItem.tres"),
        load("res://src/Resources/items/PoisonHit.tres"),
        load("res://src/Resources/items/ProjSpeed.tres"),
    ]
    for item in items:
        character.get_node("ItemHolder").add_item(item)
    var weapons: Array[BaseWeapon] = [
        load("res://src/Resources/weapons/Fist.tres"),
        load("res://src/Resources/weapons/Pistol.tres"),
        load("res://src/Resources/weapons/Shotgun.tres"),
        load("res://src/Resources/weapons/Knife.tres"),
        load("res://src/Resources/weapons/Thorns.tres"),
    ]
    character.get_node("WeaponHolder").weapons.append_array(weapons)

    shop._update_character_info()
    # The menu hides its whole layer in `_ready()`, and a hidden layer is never
    # laid out, so the grid would never assign the tiles a position.
    shop.visible = true
    # Two frames: one to add the tiles, one for the grid to lay them out.
    await get_tree().process_frame
    await get_tree().process_frame

    # Both lists are grids of the shared tile, at the same compact scale the
    # character menu uses - so gear looks identical in the shop and in the
    # pause menu instead of being a one-off widget here.
    var expected_size: Vector2 = IconCard.CARD_SIZE * IconCard.COMPACT_SCALE
    for pair in [[shop.collected_items_container, items], [shop.weapons_container, weapons]]:
        var grid: GridContainer = pair[0]
        var resources: Array = pair[1]
        assert_that(grid is GridContainer).is_true()
        assert_int(grid.columns).is_equal(5)
        assert_int(grid.get_child_count()).is_equal(resources.size())
        for index in resources.size():
            var card: Control = grid.get_child(index)
            assert_that(card is IconCard).is_true()
            assert_vector(card.custom_minimum_size).is_equal(expected_size)
            assert_str((card as IconCard).name_label.text).is_equal(
                ItemDisplayPanel.display_name(resources[index]))
            assert_int((card as IconCard).icon_holder.get_child_count()).is_equal(1)

    # 6 tiles in 5 columns wrap onto a second row, exactly like the character menu.
    var first_row_y: float = (shop.collected_items_container.get_child(0) as Control).position.y
    assert_float((shop.collected_items_container.get_child(4) as Control).position.y).is_equal(first_row_y)
    assert_bool((shop.collected_items_container.get_child(5) as Control).position.y > first_row_y).is_true()

    # Hovering a collected item still drives the shared tooltip.
    var card: Control = shop.collected_items_container.get_child(0)
    card.emit_signal("mouse_entered")
    assert_bool(shop.tooltip.visible).is_true()
    assert_str(shop.tooltip.name_label.text).contains("Armour Plate")
    card.emit_signal("mouse_exited")
    assert_bool(shop.tooltip.visible).is_false()

    character.free()
    shop.free()


func test_buy_button_uses_card() -> void:
    var shop = load(SHOP_SCENE).instantiate()
    add_child(shop)
    var character := _build_character()
    shop.character = character
    # Hand-built Character never enters the tree, so wire the @onready shortcut manually.
    character.stats = character.get_node("Stats")
    character.get_node("Stats").set_base_stat("money", 5)

    var item: Item = load(PLUS_DAMAGE_ITEM)
    shop._add_shop_item_entry(item)
    var card: ShopItemCard = shop.items_container.get_child(0)
    card.primary_button.pressed.emit()

    var holder: ItemHolder = character.get_node("ItemHolder")
    assert_int(holder.items.size()).is_equal(1)
    assert_float(character.get_node("Stats").stats.get("money", 0.0)).is_equal(4.0)

    character.free()
    shop.free()


func test_sell_button_uses_analyzer_price() -> void:
    var shop = load(SHOP_SCENE).instantiate()
    add_child(shop)
    var character := _build_character()
    shop.character = character
    character.stats = character.get_node("Stats")
    character.get_node("Stats").set_base_stat("money", 0)

    var modifier: Item = load("res://src/Resources/items/CritGlass.tres")
    shop._add_item_entry(modifier)
    var card: ShopItemCard = shop.items_container.get_child(0)
    assert_str(card.secondary_button.text).is_equal("Sell (+2)")
    card.secondary_button.pressed.emit()

    assert_float(character.get_node("Stats").stats.get("money", 0.0)).is_equal(2.0)

    character.free()
    shop.free()


func test_card_text_is_scrollable() -> void:
    var card: ShopItemCard = load(CARD_SCENE).instantiate()
    add_child(card)
    var item: Item = load(PLUS_DAMAGE_ITEM)
    card.set_item_display(item)

    # Long tooltip text lives inside a ScrollContainer between icon and buttons.
    var scroll: ScrollContainer = card.get_node("Margin/VBox/InfoScroll")
    assert_that(scroll).is_not_null()
    assert_that(card.info_scroll).is_same(card.get_node("Margin/VBox/InfoScroll"))
    assert_that(card.info_label.get_parent()).is_same(scroll)
    assert_int(scroll.horizontal_scroll_mode).is_equal(ScrollContainer.SCROLL_MODE_DISABLED)
    assert_int(scroll.size_flags_vertical & Control.SIZE_EXPAND_FILL).is_equal(Control.SIZE_EXPAND_FILL)

    # Header and buttons stay outside the scrollable area.
    assert_that(card.primary_button.get_parent().get_parent()).is_same(card.get_node("Margin/VBox"))

    card.free()


# --- new card structure -----------------------------------------------------

func test_card_shows_item_name_in_header() -> void:
    var card: ShopItemCard = load(CARD_SCENE).instantiate()
    add_child(card)
    var item: Item = load(PLUS_DAMAGE_ITEM)
    card.set_item_display(item)

    assert_str(card.name_label.text).is_equal("Damage Amulet")
    # The name is not repeated in the body.
    assert_bool(card.info_label.text.contains("Damage Amulet")).is_false()

    card.free()


func test_card_marks_only_weapon_cards() -> void:
    var card: ShopItemCard = load(CARD_SCENE).instantiate()
    add_child(card)

    card.set_item_display(load(PLUS_DAMAGE_ITEM))
    assert_bool(card.is_weapon).is_false()
    assert_bool(card.type_badge.visible).is_false()

    card.set_item_display(load("res://src/Resources/weapons/Pistol.tres"))
    assert_bool(card.is_weapon).is_true()
    assert_bool(card.type_badge.visible).is_true()

    card.free()


func test_card_rows_map_positive_and_negative_tones() -> void:
    var positive: Array = ItemTooltip.card_rows(load(PLUS_DAMAGE_ITEM))
    assert_int(positive.size()).is_equal(2)  # name + one flat stat
    var stat_row: ItemCardRow = positive[1]
    assert_int(stat_row.kind).is_equal(ItemCardRow.Kind.STAT)
    assert_int(stat_row.tone).is_equal(ItemCardRow.Tone.POSITIVE)
    assert_str(stat_row.value).is_equal("+5")
    assert_str(stat_row.label).is_equal("Damage")
    assert_that(stat_row.icon).is_not_null()

    # A negative modifier reads as a loss.
    var negative: Array = ItemTooltip.card_rows(load("res://src/Resources/items/ProjSlow.tres"))
    var negative_row: ItemCardRow = negative[1]
    assert_int(negative_row.tone).is_equal(ItemCardRow.Tone.NEGATIVE)
    assert_str(negative_row.value).is_equal("-0.5")

    # Buff payload rows are always a gain, even when the effect is a slow.
    var buff: Array = ItemTooltip.card_rows(load("res://src/Resources/items/HealOnEvent.tres"))
    assert_int(buff.size()).is_greater(1)


func test_card_body_colors_by_tone() -> void:
    var card: ShopItemCard = load(CARD_SCENE).instantiate()
    add_child(card)
    card.set_item_display(load(PLUS_DAMAGE_ITEM))

    # The positive stat renders with the green tone color, not the neutral one.
    assert_str(card.info_label.text).contains(ShopItemCard.COLOR_POSITIVE.to_html(false))
    assert_str(card.info_label.text).contains("+5 Damage")

    card.free()


func test_debuff_card_shows_its_payload_as_a_gain() -> void:
    # A debuff lands on the enemy, so on the card it is something the player
    # wants: green like a buff, even though the stat value itself is negative.
    var item: Item = ItemBuilder.make_debuff_item(
        "Debuff Crit",
        "Grants a debuff: decreases critical_multiplier.",
        "critical_multiplier",
        {"flat": -0.12},
        load("res://src/Systems/Items/Buffs/DebuffSource.tscn")
    )
    var card: ShopItemCard = load(CARD_SCENE).instantiate()
    add_child(card)
    card.set_item_display(item)

    var body: String = card.info_label.text
    assert_str(body).contains("[color=#%s]-0.12 Critical Multiplier[/color]" % ItemDisplayPanel.COLOR_POSITIVE.to_html(false))
    assert_str(body).contains(ItemDisplayPanel.COLOR_POSITIVE.to_html(false))

    card.free()


func test_buff_and_debuff_flavor_ends_with_a_colon_not_a_period() -> void:
    # The grey sentence introduces the stat line under it, so a full stop would
    # close the sentence before the number that completes it. A trailing ':' ties
    # the two together. The buff reads the same way as the debuff.
    var debuff: Item = ItemBuilder.make_debuff_item(
        "Debuff Crit",
        "Grants a debuff: decreases critical_multiplier.",
        "critical_multiplier",
        {"flat": -0.12},
        load("res://src/Systems/Items/Buffs/DebuffSource.tscn")
    )
    var buff: Item = ItemBuilder.make_buff_item(
        "Buff Crit",
        "Grants a temporary buff: increases critical_multiplier.",
        "critical_multiplier",
        {"flat": 0.09},
        load("res://src/Systems/Items/Buffs/buff.tscn")
    )

    for item in [debuff, buff]:
        var rows: Array = ItemTooltip.card_rows(item)
        var flavor: ItemCardRow = rows[1]
        assert_int(flavor.kind).override_failure_message(
            "'%s' has no flavor row" % item.name).is_equal(ItemCardRow.Kind.FLAVOR)
        assert_str(flavor.text).override_failure_message(
            "'%s' does not hand its stat line over" % item.name).ends_with(":")
        assert_bool(flavor.text.ends_with(".")).override_failure_message(
            "'%s' still ends on a full stop" % item.name).is_false()


func test_card_price_plate_reflects_price() -> void:
    var card: ShopItemCard = load(CARD_SCENE).instantiate()
    add_child(card)

    card.set_price(4)
    assert_str(card.price_label.text).is_equal("4 coins")

    card.free()


func test_card_disables_buy_when_unaffordable() -> void:
    var card: ShopItemCard = load(CARD_SCENE).instantiate()
    add_child(card)

    card.set_affordable(false)
    assert_bool(card.primary_button.disabled).is_true()

    card.set_affordable(true)
    assert_bool(card.primary_button.disabled).is_false()

    card.free()


func test_card_locked_state_is_reflected() -> void:
    var shop = load(SHOP_SCENE).instantiate()
    add_child(shop)
    shop.character = _build_character()
    shop._shop_entry_id_counter = 0

    var item: Item = load(PLUS_DAMAGE_ITEM)
    shop._add_shop_item_entry(item)
    var card: ShopItemCard = shop.items_container.get_child(0)

    assert_str(card.secondary_button.text).is_equal("Lock")
    card.secondary_button.pressed.emit()
    assert_str(card.secondary_button.text).is_equal("Unlock")
    assert_int(shop.locked_items.size()).is_equal(1)

    card.secondary_button.pressed.emit()
    assert_str(card.secondary_button.text).is_equal("Lock")
    assert_int(shop.locked_items.size()).is_equal(0)

    shop.character.free()
    shop.free()


func test_shop_disables_buy_when_money_is_short() -> void:
    var shop = load(SHOP_SCENE).instantiate()
    add_child(shop)
    var character := _build_character()
    shop.character = character
    character.stats = character.get_node("Stats")
    character.get_node("Stats").set_base_stat("money", 0)

    # Weapons cost 5, so with 0 money the card must be unbuyable.
    shop._add_shop_item_entry(load("res://src/Resources/weapons/Pistol.tres"))
    var card: ShopItemCard = shop.items_container.get_child(0)
    assert_int(card.price).is_equal(5)
    assert_bool(card.primary_button.disabled).is_true()

    # A disabled card must not spend money when pressed anyway.
    card.primary_button.pressed.emit()
    assert_float(character.get_node("Stats").stats.get("money", 0.0)).is_equal(0.0)

    # With 6 money a 1-cost stat item is affordable and the purchase succeeds.
    character.get_node("Stats").set_base_stat("money", 6)
    shop._add_shop_item_entry(load(PLUS_DAMAGE_ITEM))
    var cheap: ShopItemCard = shop.items_container.get_child(1)
    assert_int(cheap.price).is_equal(1)
    assert_bool(cheap.primary_button.disabled).is_false()
    cheap.primary_button.pressed.emit()
    assert_float(character.get_node("Stats").stats.get("money", 0.0)).is_equal(5.0)

    # With 5 money the 5-cost weapon is affordable again.
    shop._refresh_affordability()
    assert_bool(card.primary_button.disabled).is_false()

    character.free()
    shop.free()


func test_selling_pickup_refreshes_other_cards_affordability() -> void:
    var shop = load(SHOP_SCENE).instantiate()
    add_child(shop)
    var character := _build_character()
    shop.character = character
    character.stats = character.get_node("Stats")
    character.get_node("Stats").set_base_stat("money", 0)

    # A 5-cost weapon the player cannot afford yet.
    shop._add_shop_item_entry(load("res://src/Resources/weapons/Pistol.tres"))
    var weapon_card: ShopItemCard = shop.items_container.get_child(0)
    assert_bool(weapon_card.primary_button.disabled).is_true()

    # Selling a pickup worth 2 still leaves the 5-cost weapon unaffordable.
    shop._add_item_entry(load("res://src/Resources/items/CritGlass.tres"))
    var first_pickup: ShopItemCard = shop.items_container.get_child(1)
    first_pickup.secondary_button.pressed.emit()
    assert_float(character.get_node("Stats").stats.get("money", 0.0)).is_equal(2.0)
    assert_bool(weapon_card.primary_button.disabled).is_true()

    # Sold cards free on a tween, so look the new pickup up by identity rather
    # than by index.
    shop._add_item_entry(load("res://src/Resources/items/CritGlass.tres"))
    for child in shop.items_container.get_children():
        if child != first_pickup and child is ShopItemCard and not child.has_meta("id"):
            (child as ShopItemCard).secondary_button.pressed.emit()
            break
    assert_float(character.get_node("Stats").stats.get("money", 0.0)).is_equal(4.0)
    assert_bool(weapon_card.primary_button.disabled).is_true()

    # One more sale crosses the 5 coin threshold and re-enables the weapon.
    shop._add_item_entry(load("res://src/Resources/items/CritGlass.tres"))
    for child in shop.items_container.get_children():
        if child is ShopItemCard and not child.has_meta("id") and not child.is_queued_for_deletion():
            (child as ShopItemCard).secondary_button.pressed.emit()
            break
    assert_float(character.get_node("Stats").stats.get("money", 0.0)).is_equal(6.0)
    assert_bool(weapon_card.primary_button.disabled).is_false()

    character.free()
    shop.free()
