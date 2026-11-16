## Weapon slots, combining and rarity: a holder with `max_weapons` refuses a
## weapon past the limit, two identical weapons merge into one of the next
## rarity, and rarity scales the weapon's damage and colours its icon tile.
class_name WeaponRarityCombineTest
extends GdUnitTestSuite

const PISTOL := "res://src/Resources/weapons/Pistol.tres"
const SHOP_SCENE := "res://src/Scenes/menu/ShopMenu.tscn"
const ICON_CARD_SCENE := "res://src/ui/IconCard.tscn"


func _build_character(max_weapons: int) -> Character:
    var character: Character = auto_free(Character.new())
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
    weapon_holder.max_weapons = max_weapons
    character.add_child(weapon_holder)
    return character


## A pistol under another name, so it is a different weapon to the combiner.
func _named_pistol(weapon_name: String) -> BaseWeapon:
    var weapon: BaseWeapon = load(PISTOL).duplicate(true)
    weapon.name = weapon_name
    return weapon


## Fills every slot with a weapon that combines with nothing.
func _fill(holder: WeaponHolder) -> void:
    for i in holder.max_weapons - holder.weapons.size():
        holder.add_weapon(_named_pistol("Filler%d" % i))


## The table is the feature's spec (1 / 1.3 / 1.6 / 1.9 / 2.5), not a balance
## value read from a `.tres`, so it is pinned literally.
func test_rarity_multiplies_the_weapon_damage() -> void:
    assert_array(BaseWeapon.RARITY_DAMAGE_MULTIPLIERS).is_equal([1.0, 1.3, 1.6, 1.9, 2.5])

    var weapon: BaseWeapon = load(PISTOL).duplicate(true)
    for rarity in BaseWeapon.Rarity.values():
        weapon.rarity = rarity
        var expected: float = weapon.base_damage * BaseWeapon.RARITY_DAMAGE_MULTIPLIERS[rarity]
        assert_float(weapon.rarity_damage()).is_equal_approx(expected, 0.0001)
        assert_float(weapon.current_damage).is_equal_approx(expected, 0.0001)


func test_the_player_holder_is_limited_to_six_weapons() -> void:
    # Six is the requested limit, authored on the player's scene.
    var character: Character = auto_free(load("res://src/Systems/Character.tscn").instantiate())
    assert_int(character.weapon_holder.max_weapons).is_equal(6)


func test_a_full_holder_refuses_a_weapon_it_cannot_combine() -> void:
    var holder := _build_character(6).weapon_holder
    _fill(holder)
    assert_int(holder.weapons.size()).is_equal(6)

    assert_bool(holder.can_add_weapon(_named_pistol("Other"))).is_false()
    assert_bool(holder.add_weapon(_named_pistol("Other"))).is_false()
    assert_int(holder.weapons.size()).is_equal(6)


func test_an_unlimited_holder_takes_more_than_six() -> void:
    # Enemies keep `max_weapons = 0`; the boss carries up to ten.
    var holder := _build_character(0).weapon_holder
    for i in 8:
        assert_bool(holder.add_weapon(load(PISTOL))).is_true()
    assert_int(holder.weapons.size()).is_equal(8)


func test_combining_two_identical_weapons_leaves_one_of_the_next_rarity() -> void:
    var holder := _build_character(6).weapon_holder
    holder.add_weapon(load(PISTOL))
    holder.add_weapon(load(PISTOL))
    var kept: BaseWeapon = holder.weapons[0]
    var damage_before: float = kept.current_damage

    assert_bool(holder.combine(kept)).is_true()

    assert_int(holder.weapons.size()).is_equal(1)
    assert_object(holder.weapons[0]).is_same(kept)
    assert_int(kept.rarity).is_equal(BaseWeapon.Rarity.UNCOMMON)
    assert_float(kept.current_damage).is_greater(damage_before)
    # Nothing left to combine with.
    assert_bool(holder.combine(kept)).is_false()


func test_only_the_same_weapon_at_the_same_rarity_combines() -> void:
    var holder := _build_character(6).weapon_holder
    holder.add_weapon(load(PISTOL))
    holder.add_weapon(_named_pistol("Other"))
    holder.add_weapon(load(PISTOL))
    holder.weapons[2].rarity = BaseWeapon.Rarity.RARE

    for weapon in holder.weapons.duplicate():
        assert_bool(holder.combine(weapon)).is_false()
    assert_int(holder.weapons.size()).is_equal(3)


func test_legendary_is_the_last_rarity() -> void:
    var holder := _build_character(6).weapon_holder
    holder.add_weapon(load(PISTOL))
    holder.add_weapon(load(PISTOL))
    for weapon in holder.weapons:
        weapon.rarity = BaseWeapon.Rarity.LEGENDARY

    assert_bool(holder.combine(holder.weapons[0])).is_false()
    assert_int(holder.weapons.size()).is_equal(2)


func test_a_duplicate_added_to_a_full_holder_combines_instead() -> void:
    var holder := _build_character(6).weapon_holder
    holder.add_weapon(load(PISTOL))
    _fill(holder)

    assert_bool(holder.add_weapon(load(PISTOL))).is_true()

    assert_int(holder.weapons.size()).is_equal(6)
    assert_int(holder.weapons[0].rarity).is_equal(BaseWeapon.Rarity.UNCOMMON)


func test_shop_disables_buying_a_weapon_with_no_free_slot() -> void:
    var shop: ShopMenu = auto_free(load(SHOP_SCENE).instantiate())
    add_child(shop)
    var character := _build_character(6)
    shop.character = character
    character.stats.set_base_stat("money", 1000)
    _fill(character.weapon_holder)

    shop._add_shop_item_entry(_named_pistol("Other"))
    shop._add_shop_item_entry(_named_pistol("Filler0"))
    var blocked: ShopItemCard = shop.items_container.get_child(0)
    var combinable: ShopItemCard = shop.items_container.get_child(1)

    assert_bool(blocked.primary_button.disabled).is_true()
    blocked.primary_button.pressed.emit()
    assert_int(character.weapon_holder.weapons.size()).is_equal(6)
    assert_float(character.stats.stats.get("money", 0.0)).is_equal(1000.0)

    # A duplicate of a held weapon is still buyable: it combines.
    assert_bool(combinable.primary_button.disabled).is_false()
    combinable.primary_button.pressed.emit()
    assert_int(character.weapon_holder.weapons.size()).is_equal(6)
    assert_int(character.weapon_holder.weapons[0].rarity).is_equal(BaseWeapon.Rarity.UNCOMMON)


func test_clicking_a_weapon_tile_in_the_shop_combines_it() -> void:
    var shop: ShopMenu = auto_free(load(SHOP_SCENE).instantiate())
    add_child(shop)
    var character := _build_character(6)
    shop.character = character
    var holder: WeaponHolder = character.weapon_holder
    holder.add_weapon(load(PISTOL))
    holder.add_weapon(load(PISTOL))
    holder.add_weapon(_named_pistol("Other"))
    shop._update_character_info()

    # Only a tile with a duplicate offers the button.
    assert_object(shop.weapons_container.get_child(2).get_node_or_null("CombineButton")).is_null()
    var button: Button = shop.weapons_container.get_child(0).get_node_or_null("CombineButton")
    assert_object(button).is_not_null()

    button.pressed.emit()
    assert_int(holder.weapons.size()).is_equal(2)
    assert_int(holder.weapons[0].rarity).is_equal(BaseWeapon.Rarity.UNCOMMON)
    await get_tree().process_frame
    # Nothing left to combine, so the rebuilt tiles carry no button.
    for tile in shop.weapons_container.get_children():
        assert_object(tile.get_node_or_null("CombineButton")).is_null()


## Tiles for the weapons held, then one empty rectangle per free slot, under a
## heading that counts both. The shop and the character menu share the rule.
func test_weapon_lists_show_the_count_and_the_empty_slots() -> void:
    var character := _build_character(6)
    var holder: WeaponHolder = character.weapon_holder
    holder.add_weapon(load(PISTOL))
    holder.add_weapon(_named_pistol("Other"))
    var title := "Weapons %d/%d" % [holder.weapons.size(), holder.max_weapons]

    var shop: ShopMenu = auto_free(load(SHOP_SCENE).instantiate())
    add_child(shop)
    shop.character = character
    shop._update_character_info()

    var prev_character: Character = GlobalGameState.current_character
    GlobalGameState.current_character = character
    var ui = auto_free(load("res://src/ui/CharacterUI.tscn").instantiate())
    add_child(ui)
    GlobalGameState.current_character = prev_character if is_instance_valid(prev_character) else null

    for pair in [[shop.weapons_container, shop.weapons_label], [ui.weapons_container, ui.weapons_label]]:
        var tiles: Array = pair[0].get_children().filter(
            func(c: Node) -> bool: return not c.is_queued_for_deletion())
        assert_str(pair[1].text).is_equal(title)
        assert_int(tiles.size()).is_equal(holder.max_weapons)
        assert_int(tiles.filter(func(c: Node) -> bool: return c is IconCard).size()) \
                .is_equal(holder.weapons.size())


func test_an_unlimited_holder_shows_no_count_and_no_empty_slots() -> void:
    var character := _build_character(0)
    character.weapon_holder.add_weapon(load(PISTOL))
    var shop: ShopMenu = auto_free(load(SHOP_SCENE).instantiate())
    add_child(shop)
    shop.character = character
    shop._update_character_info()

    assert_str(shop.weapons_label.text).is_equal("Weapons")
    assert_int(shop.weapons_container.get_child_count()).is_equal(1)


func test_icon_tile_border_shows_the_rarity() -> void:
    var weapon: BaseWeapon = load(PISTOL).duplicate(true)
    var colors_seen: Array[Color] = []
    for rarity in BaseWeapon.Rarity.values():
        weapon.rarity = rarity
        var card: IconCard = auto_free(load(ICON_CARD_SCENE).instantiate())
        add_child(card)
        card.set_display(weapon)
        var border: Color = (card.get_theme_stylebox("panel") as StyleBoxFlat).border_color
        # Common keeps the plain tile border; every rarity above has its own.
        var expected: Color = ItemDisplayPanel.PANEL_BORDER if rarity == BaseWeapon.Rarity.COMMON \
                else BaseWeapon.RARITY_COLORS[rarity]
        assert_bool(border.is_equal_approx(expected)).is_true()
        assert_bool(colors_seen.has(border)).is_false()
        colors_seen.append(border)
