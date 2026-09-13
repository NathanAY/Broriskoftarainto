# GdUnit TestSuite for the shared TooltipUi / CharacterUI / ShopMenu tooltip features
class_name CharacterUiTooltipTest
extends GdUnitTestSuite

const CHARACTER_UI_SCENE := "res://src/ui/CharacterUI.tscn"
const SHOP_SCENE := "res://src/Scenes/menu/ShopMenu.tscn"
const PISTOL_WEAPON := "res://src/Resources/weapons/Pistol.tres"
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


func test_weapon_tooltip_lines() -> void:
    var weapon: BaseWeapon = load(PISTOL_WEAPON)
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(weapon)
    assert_that(lines).contains("name: Pistol")
    assert_that(lines).contains("damage: 5.0")
    assert_that(lines).contains("range: 400.0")
    assert_that(lines).contains("attack speed: 0.8")
    assert_that(lines).contains("description: Pistol")


func test_item_tooltip_lines() -> void:
    var item: Item = load(PLUS_DAMAGE_ITEM)
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    assert_that(lines).contains("name: Damage Amulet")
    assert_that(lines).contains("description: Increase damage by 5")
    assert_that(lines).contains("damage flat: 5.0")


func test_hover_shows_and_hides_tooltip() -> void:
    var character := _build_character()
    var prev_character: Character = GlobalGameState.current_character
    GlobalGameState.current_character = character

    var ui = load(CHARACTER_UI_SCENE).instantiate()
    var item: Item = load(PLUS_DAMAGE_ITEM)
    character.get_node("ItemHolder").add_item(item)
    add_child(ui)

    assert_bool(ui.tooltip.visible).is_false()

    var row: Control = ui.items_container.get_child(0)
    row.emit_signal("mouse_entered")
    assert_bool(ui.tooltip.visible).is_true()
    assert_str(ui.tooltip.label.text).contains("Damage Amulet")

    row.emit_signal("mouse_exited")
    assert_bool(ui.tooltip.visible).is_false()

    GlobalGameState.current_character = prev_character
    ui.free()
    character.free()


func test_tooltip_ui_bind_to_row() -> void:
    var tooltip_ui = load("res://src/ui/TooltipUi.tscn").instantiate()
    add_child(tooltip_ui)

    var item: Item = load(PLUS_DAMAGE_ITEM)
    var row: Control = HBoxContainer.new()
    row.add_child(Label.new())
    add_child(row)

    tooltip_ui.bind_to_row(row, item)
    assert_bool(tooltip_ui.visible).is_false()

    row.emit_signal("mouse_entered")
    assert_bool(tooltip_ui.visible).is_true()
    assert_str(tooltip_ui.label.text).contains("name: Damage Amulet")

    row.emit_signal("mouse_exited")
    assert_bool(tooltip_ui.visible).is_false()

    row.free()
    tooltip_ui.free()


func test_shop_menu_character_info_tooltips() -> void:
    var character := _build_character()
    var item: Item = load(PLUS_DAMAGE_ITEM)
    var weapon: BaseWeapon = load(PISTOL_WEAPON)
    character.get_node("ItemHolder").add_item(item)
    character.get_node("WeaponHolder").weapons.append(weapon)

    var shop = load(SHOP_SCENE).instantiate()
    add_child(shop)
    shop.character = character
    shop._update_character_info()

    # Items
    assert_int(shop.collected_items_container.get_child_count()).is_equal(1)
    var item_row: Control = shop.collected_items_container.get_child(0)
    item_row.emit_signal("mouse_entered")
    assert_bool(shop.tooltip.visible).is_true()
    assert_str(shop.tooltip.label.text).contains("name: Damage Amulet")
    item_row.emit_signal("mouse_exited")
    assert_bool(shop.tooltip.visible).is_false()

    # Weapons
    assert_int(shop.weapons_container.get_child_count()).is_equal(1)
    var weapon_row: Control = shop.weapons_container.get_child(0)
    weapon_row.emit_signal("mouse_entered")
    assert_bool(shop.tooltip.visible).is_true()
    assert_str(shop.tooltip.label.text).contains("name: Pistol")
    weapon_row.emit_signal("mouse_exited")
    assert_bool(shop.tooltip.visible).is_false()

    shop.free()
    character.free()
