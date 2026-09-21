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
    assert_that(card.get_node("Margin/VBox/IconHolder")).is_not_null()
    assert_that(card.get_node("Margin/VBox/InfoScroll")).is_not_null()
    assert_that(card.get_node("Margin/VBox/InfoScroll/InfoLabel")).is_not_null()

    var vbox: VBoxContainer = card.get_node("Margin/VBox")
    assert_int(vbox.get_node("IconHolder").get_index()).is_less(vbox.get_node("InfoScroll").get_index())
    assert_int(vbox.get_node("InfoScroll").get_index()).is_less(vbox.get_node("Buttons").get_index())

    # Text matches ItemTooltip formatting.
    var expected: String = "\n\n".join(ItemTooltip.tooltip_lines(item))
    assert_str(card.info_label.text).is_equal(expected)

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
    assert_str(shop_card.primary_button.text).is_equal("Buy")
    assert_str(shop_card.secondary_button.text).is_equal("Lock")
    assert_str(shop_card.info_label.text).is_equal("\n\n".join(ItemTooltip.tooltip_lines(item)))
    assert_int(shop_card.icon_holder.get_child_count()).is_equal(1)

    var pickup_card: ShopItemCard = shop.items_container.get_child(1)
    assert_str(pickup_card.primary_button.text).is_equal("Take")
    assert_str(pickup_card.secondary_button.text).is_equal("Sell")
    assert_str(pickup_card.info_label.text).is_equal("\n\n".join(ItemTooltip.tooltip_lines(item)))

    shop.character.free()
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
    assert_that(card.icon_holder.get_parent().get_parent()).is_same(card.get_node("Margin"))
    assert_that(card.primary_button.get_parent().get_parent()).is_same(card.get_node("Margin/VBox"))

    card.free()
