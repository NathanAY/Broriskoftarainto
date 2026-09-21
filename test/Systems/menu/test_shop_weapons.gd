# GdUnit TestSuite for shop selling weapons (10% chance per offer).
class_name ShopWeaponsTest
extends GdUnitTestSuite

const SHOP_SCENE := "res://src/Scenes/menu/ShopMenu.tscn"
const CARD_SCENE := "res://src/Scenes/menu/ShopItemCard.tscn"
const PISTOL_WEAPON := "res://src/Resources/weapons/Pistol.tres"


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


func test_card_displays_weapon() -> void:
    var card: ShopItemCard = load(CARD_SCENE).instantiate()
    add_child(card)
    var weapon: BaseWeapon = load(PISTOL_WEAPON)
    card.set_item_display(weapon)

    assert_int(card.icon_holder.get_child_count()).is_equal(1)
    assert_str(card.info_label.text).is_equal("\n\n".join(ItemTooltip.tooltip_lines(weapon)))
    assert_str(card.info_label.text).contains(weapon.name)

    card.free()


func test_buy_weapon_equips_in_weapon_holder() -> void:
    var shop = load(SHOP_SCENE).instantiate()
    add_child(shop)
    var character := _build_character()
    shop.character = character
    character.stats = character.get_node("Stats")
    character.get_node("Stats").set_base_stat("money", 5)
    # Character stays off-tree, so wire WeaponHolder's onready refs manually.
    var weapon_holder: WeaponHolder = character.get_node("WeaponHolder")
    weapon_holder.hold_owner = character
    weapon_holder.event_manager = character.get_node("EventManager")

    var weapon: BaseWeapon = load(PISTOL_WEAPON)
    shop._add_shop_item_entry(weapon)
    var card: ShopItemCard = shop.items_container.get_child(0)
    card.primary_button.pressed.emit()

    assert_int(weapon_holder.weapons.size()).is_equal(1)
    assert_float(character.get_node("Stats").stats.get("money", 0.0)).is_equal(4.0)

    weapon_holder.weapons = []
    character.free()
    shop.free()


func test_factory_returns_random_weapon() -> void:
    var factory: ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
    add_child(factory)
    var weapon: BaseWeapon = factory.get_random_weapon()
    assert_that(weapon).is_not_null()
    assert_that(weapon is BaseWeapon).is_true()
    assert_str(weapon.name).is_not_empty()
    collect_orphan_node_details()


func test_shop_offer_generation_mixes_weapons_and_items() -> void:
    var shop = load(SHOP_SCENE).instantiate()
    add_child(shop)
    var factory: ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
    add_child(factory)
    factory.rng.seed = 12345
    shop.item_factory = factory

    var saw_weapon := false
    var saw_item := false
    for i in range(60):
        var offer: Resource = shop._generate_shop_offer()
        assert_that(offer).is_not_null()
        if offer is BaseWeapon:
            saw_weapon = true
        else:
            saw_item = true

    assert_bool(saw_weapon).is_true()
    assert_bool(saw_item).is_true()

    collect_orphan_node_details()