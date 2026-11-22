extends GdUnitTestSuite
## An equipped weapon's tooltip shows the holder-scaled value after the base one:
## "Damage: 10 (16)". Expectations are derived from the weapon and the stats
## under test, never from `.tres` balance numbers.

const PISTOL_WEAPON := "res://src/Resources/weapons/Pistol.tres"


func _make_stats() -> Stats:
    var event_manager := EventManager.new()
    var stats := Stats.new()
    stats.event_manager = event_manager
    stats.add_child(event_manager)
    return auto_free(stats)


func _row(weapon: BaseWeapon, label: String) -> String:
    for row in ItemTooltip.weapon_card_rows(weapon):
        var typed: ItemCardRow = row
        if typed.kind == ItemCardRow.Kind.WEAPON and typed.label == label:
            return typed.value
    return ""


func test_unbound_weapon_shows_base_only() -> void:
    var weapon: BaseWeapon = load(PISTOL_WEAPON).duplicate()
    assert_str(_row(weapon, "Damage")).is_equal(ItemTooltip.format_value(weapon.rarity_damage()))
    assert_str(_row(weapon, "Attack Speed")).not_contains("(")


func test_bound_weapon_shows_final_values_in_parentheses() -> void:
    var weapon: BaseWeapon = load(PISTOL_WEAPON).duplicate()
    var stats := _make_stats()
    stats.set_base_stat("damage", 1.6)
    stats.set_base_stat("flat_weapon_damage", 2.0)
    stats.set_base_stat("attack_speed", 1.5)
    weapon.stats = stats

    var base_damage := ItemTooltip.format_value(snappedf(weapon.rarity_damage(), 0.01))
    var final_damage := ItemTooltip.format_value(snappedf(weapon.current_damage, 0.01))
    assert_str(_row(weapon, "Damage")).is_equal("%s (%s)" % [base_damage, final_damage])

    var base_speed := ItemTooltip.format_value(snappedf(weapon.base_attack_speed, 0.01))
    var final_speed := ItemTooltip.format_value(snappedf(weapon.base_attack_speed * 1.5, 0.01))
    assert_str(_row(weapon, "Attack Speed")).is_equal("%s (%s) attack/sec" % [base_speed, final_speed])


func test_unequipped_weapon_uses_passed_holder_stats() -> void:
    # A shop offer is not equipped, so the shop hands it the player's stats.
    var weapon: BaseWeapon = load(PISTOL_WEAPON).duplicate()
    var stats := _make_stats()
    stats.set_base_stat("damage", 2.0)
    var expected := ItemTooltip.format_value(snappedf(weapon.damage_with(stats), 0.01))
    var value := ""
    for row in ItemTooltip.weapon_card_rows(weapon, stats):
        if (row as ItemCardRow).label == "Damage":
            value = (row as ItemCardRow).value
    assert_str(value).ends_with("(%s)" % expected)
    # ...and the offer resource itself is not bound by it.
    assert_object(weapon.stats).is_null()


func test_shop_weapon_offer_follows_player_stats() -> void:
    var character := Character.new()
    var event_manager := EventManager.new()
    event_manager.name = "EventManager"
    character.add_child(event_manager)
    var stats := Stats.new()
    stats.name = "Stats"
    stats.event_manager = event_manager
    character.add_child(stats)
    auto_free(character)

    var shop = auto_free(load("res://src/Scenes/menu/ShopMenu.tscn").instantiate())
    add_child(shop)
    shop.character = character
    var weapon: BaseWeapon = load(PISTOL_WEAPON)
    shop._add_shop_item_entry(weapon)
    var card: ShopItemCard = shop.items_container.get_child(shop.items_container.get_child_count() - 1)
    # Neutral stats: base number only.
    assert_str(card.info_label.text).not_contains("(")

    stats.set_base_stat("damage", 2.0)
    shop._update_stats()
    var expected := ItemTooltip.format_value(snappedf(weapon.damage_with(stats), 0.01))
    assert_str(card.info_label.text).contains("(%s)" % expected)


func test_neutral_stats_add_no_parentheses() -> void:
    # Default stats (damage 1, no flat, attack_speed 1) do not change anything,
    # so the card stays as short as an unequipped weapon's.
    var weapon: BaseWeapon = load(PISTOL_WEAPON).duplicate()
    weapon.stats = _make_stats()
    assert_str(_row(weapon, "Damage")).not_contains("(")
    assert_str(_row(weapon, "Attack Speed")).not_contains("(")
