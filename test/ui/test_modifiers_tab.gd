# GdUnit TestSuite for the character menu's Modifiers tab (ModifierSummary + CharacterUI)
class_name ModifiersTabTest
extends GdUnitTestSuite

const CHARACTER_UI_SCENE := "res://src/ui/CharacterUI.tscn"
const KNOCKBACK_ITEM := "res://src/Resources/items/Knockback.tres"
const POISON_ITEM := "res://src/Resources/items/PoisonHit.tres"
const REGEN_MODIFIER := "res://src/Systems/Items/modifiers/FlatRegenModifier.tscn"
const PISTOL := "res://src/Resources/weapons/Pistol.tres"


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


func _names(entries: Array[Dictionary]) -> Array[String]:
    var names: Array[String] = []
    for entry in entries:
        names.append(str(entry["display"]["name"]))
    return names


func _entry(entries: Array[Dictionary], display_name: String) -> Dictionary:
    for entry in entries:
        if str(entry["display"]["name"]) == display_name:
            return entry
    return {}


func test_no_modifiers_gives_no_entries() -> void:
    var character := _build_character()
    assert_array(ModifierSummary.entries(character)).is_empty()
    assert_array(ModifierSummary.entries(null)).is_empty()
    character.free()


func test_same_modifier_from_two_items_is_one_line_with_a_count() -> void:
    var character := _build_character()
    var holder: ItemHolder = character.get_node("ItemHolder")
    var knockback: Item = load(KNOCKBACK_ITEM)
    holder.add_item(knockback)
    holder.add_item(knockback)
    holder.add_item(load(POISON_ITEM))

    var expected_name := ItemTooltip.effect_row(ItemTooltip.resolve_effect_display_for_item(knockback, 0)) \
        .text.get_slice(" — ", 0)
    var entries := ModifierSummary.entries(character)

    var found := 0
    for entry in entries:
        if ItemTooltip.humanize_effect_name(str(entry["display"]["name"])) == expected_name:
            found += 1
            assert_int(entry["count"]).is_equal(2)
    assert_int(found).is_equal(1)
    # A different modifier stays its own line.
    assert_int(entries.size()).is_greater(1)
    for entry in entries:
        assert_object(entry["texture"]).is_not_null()

    character.free()


func test_character_baseline_and_weapon_builtins_are_listed() -> void:
    var character := _build_character()
    var holder: ItemHolder = character.get_node("ItemHolder")
    var em: EventManager = character.get_node("EventManager")
    BaseModifier.attach(load(REGEN_MODIFIER), holder, em)

    var regen_display := ItemTooltip.resolve_effect_display(load(REGEN_MODIFIER))
    assert_array(_names(ModifierSummary.entries(character))).contains([regen_display["name"]])

    # A weapon's own built-in effect shows up too, though no item carries it.
    var before_names := _names(ModifierSummary.entries(character))
    var weapon: BaseWeapon = load(PISTOL)
    WeaponBuiltinEffects.attach_for_weapon(weapon, character, em)
    var after_names := _names(ModifierSummary.entries(character))
    assert_int(after_names.size()).is_greater(before_names.size())

    WeaponBuiltinEffects.detach(weapon)
    character.free()


func test_character_ui_modifiers_tab_lists_merged_rows() -> void:
    var character := _build_character()
    var prev_character: Character = GlobalGameState.current_character
    GlobalGameState.current_character = character
    var holder: ItemHolder = character.get_node("ItemHolder")
    var knockback: Item = load(KNOCKBACK_ITEM)
    holder.add_item(knockback)
    holder.add_item(knockback)

    var ui = load(CHARACTER_UI_SCENE).instantiate()
    add_child(ui)

    # Stats stays the first tab; Modifiers is the second.
    assert_int(ui.stats_tabs.get_tab_count()).is_equal(2)
    assert_str(ui.stats_tabs.get_tab_title(0)).is_equal("Stats")
    assert_str(ui.stats_tabs.get_tab_title(1)).is_equal("Modifiers")
    assert_int(ui.stats_container.get_child_count()).is_greater(0)

    var entries := ModifierSummary.entries(character)
    assert_int(ui.modifiers_container.get_child_count()).is_equal(entries.size())
    var row: Control = ui.modifiers_container.get_child(0)
    assert_str((row.get_node("Count") as Label).text).is_equal("x2")

    # A new item updates the list without reopening the menu.
    holder.add_item(load(POISON_ITEM))
    assert_int(ui.modifiers_container.get_child_count()).is_equal(ModifierSummary.entries(character).size())

    GlobalGameState.current_character = prev_character if is_instance_valid(prev_character) else null
    ui.free()
    character.free()


func test_shop_stats_panel_has_the_same_modifiers_tab() -> void:
    var character := _build_character()
    var holder: ItemHolder = character.get_node("ItemHolder")
    var knockback: Item = load(KNOCKBACK_ITEM)
    holder.add_item(knockback)
    holder.add_item(knockback)

    var shop = load("res://src/Scenes/menu/ShopMenu.tscn").instantiate()
    add_child(shop)
    shop.character = character
    shop._update_stats()
    shop._update_character_info()

    var tabs: TabContainer = shop.get_node("Control/VBoxContainer/MidContainer/StatsPanel/StatsTabs")
    assert_str(tabs.get_tab_title(0)).is_equal("Stats")
    assert_str(tabs.get_tab_title(1)).is_equal("Modifiers")
    assert_int(shop.stats_container.get_child_count()).is_greater(0)
    assert_int(shop.modifiers_container.get_child_count()).is_equal(ModifierSummary.entries(character).size())
    assert_str((shop.modifiers_container.get_child(0).get_node("Count") as Label).text).is_equal("x2")

    # Selling an item refreshes the list through the same path the shop uses.
    holder.remove_item(knockback)
    shop._update_character_info()
    assert_object(shop.modifiers_container.get_child(0).get_node_or_null("Count")).is_null()

    shop.free()
    character.free()
