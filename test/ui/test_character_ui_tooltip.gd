# GdUnit TestSuite for the shared TooltipUi / CharacterUI / ShopMenu tooltip features
class_name CharacterUiTooltipTest
extends GdUnitTestSuite

const CHARACTER_UI_SCENE := "res://src/ui/CharacterUI.tscn"
const SHOP_SCENE := "res://src/Scenes/menu/ShopMenu.tscn"
const PISTOL_WEAPON := "res://src/Resources/weapons/Pistol.tres"
const PLUS_DAMAGE_ITEM := "res://src/Resources/items/PlusDamageItem.tres"
const BUFF_SCENE := "res://src/Systems/Items/Buffs/buff.tscn"
const DEBUFF_SCENE := "res://src/Systems/Items/Buffs/DebuffSource.tscn"
const EFFECT_SCENE := "res://src/Systems/Items/Modifiers/ProjectileBounceModifier.tscn"


func _build_character() -> Character:
    var character := Character.new()
    character.name = " Character"
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
    assert_int(lines.size()).is_equal(4)


func test_item_tooltip_lines() -> void:
    var item: Item = load(PLUS_DAMAGE_ITEM)
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    assert_that(lines).contains("name: Damage Amulet")
    assert_that(lines).contains("damage flat: 5.0")
    assert_int(lines.size()).is_equal(2)


func test_stat_item_tooltip_lines_via_builder() -> void:
    # Fully deterministic: hardcoded literals, no RNG, no Stats dependency.
    var item: Item = ItemBuilder.make_stat_item(
        "Amulet of Power",
        "Increases damage by 5",
        {"damage": {"flat": 5.0}, "movement_speed": {"flat": -2.0}}
    )
    assert_object(item).is_not_null()

    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    assert_that(lines).contains("name: Amulet of Power")
    assert_that(lines).contains("damage flat: 5.0")
    assert_that(lines).contains("movement_speed flat: -2.0")
    assert_int(lines.size()).is_equal(3)


func test_stat_item_positive_and_negative_mirroring_factory() -> void:
    # Simulates ItemFactory._generate_stat_item (item_factory.gd:86-90):
    # one positive stat entry plus one negated tradeoff entry sharing one description.
    # Hardcoded literals keep it independent of Stats values and RNG.
    var value := {"flat": 0.08}
    var negative_value := {"flat": -0.05}
    var item: Item = ItemBuilder.make_stat_item(
        "Amulet of Power",
        "Increases damage for %s\nDecreasese movement_speed for %s" % [value, negative_value],
        {"damage": value, "movement_speed": negative_value}
    )
    assert_object(item).is_not_null()
    assert_bool(float(item.modifiers["damage"]["flat"]) > 0.0).is_true()
    assert_bool(float(item.modifiers["movement_speed"]["flat"]) < 0.0).is_true()

    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    assert_that(lines).contains("name: Amulet of Power")
    assert_that(lines).contains("damage flat: 0.08")
    assert_that(lines).contains("movement_speed flat: -0.05")
    assert_int(lines.size()).is_equal(3)


func test_effect_item_tooltip_lines_via_builder() -> void:
    # Fully deterministic: explicit effect scene + hardcoded tradeoff modifier.
    var scene: PackedScene = load(EFFECT_SCENE)
    assert_object(scene).is_not_null()
    var item: Item = ItemBuilder.make_effect_item(
        "Bounce",
        "Grants bouncing projectiles",
        scene,
        {"armor": {"flat": -1.0}}
    )
    assert_object(item).is_not_null()
    assert_int(item.effect_scene.size()).is_equal(1)

    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    assert_that(lines).contains("name: Bounce")
    assert_that(lines).contains("tradeoff: armor flat: -1.0")
    assert_int(lines.size()).is_equal(3)
    var found_effect := false
    for line in lines:
        if line.begins_with("effect:") and "Projectile Bounce" in line:
            found_effect = true
    assert_bool(found_effect).is_true()


func test_effect_item_with_negative_stat_mirroring_factory() -> void:
    # Simulates ItemFactory._generate_effect_item (item_factory.gd:114-127):
    # an effect scene plus a doubled negated tradeoff (factory uses -flat * 2).
    # Hardcoded literals keep it independent of Stats values and RNG.
    var scene: PackedScene = load(EFFECT_SCENE)
    assert_object(scene).is_not_null()
    var negative_value := {"flat": -0.1}
    var item: Item = ItemBuilder.make_effect_item(
        "Bounce",
        "Grants special effect: Bounce\nDecreasese armor for %s" % [negative_value],
        scene,
        {"armor": negative_value}
    )
    assert_object(item).is_not_null()
    assert_int(item.effect_scene.size()).is_equal(1)
    assert_bool(float(item.modifiers["armor"]["flat"]) < 0.0).is_true()

    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    assert_that(lines).contains("name: Bounce")
    assert_that(lines).contains("tradeoff: armor flat: -0.1")
    assert_int(lines.size()).is_equal(3)
    var found_effect := false
    for line in lines:
        if line.begins_with("effect:") and "Projectile Bounce" in line:
            found_effect = true
    assert_bool(found_effect).is_true()


func test_heal_on_event_tooltip_shows_trigger_and_amount() -> void:
    var scene: PackedScene = load("res://src/Systems/Items/Modifiers/HealOnEventModifier.tscn")
    var item: Item = ItemBuilder.make_effect_item("Heal On Event Modifier", "flavor", scene, {})
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    # Script defaults: trigger on_crit, heal 1.
    assert_that(lines).contains("effect: Heal On Event — Heals 1 HP (Triggers on crit)")


func test_heal_on_event_tooltip_follows_configured_values() -> void:
    # Simulates factory randomization (possible_trigger_event override):
    # the tooltip must show the configured trigger + heal, not defaults.
    var scene: PackedScene = load("res://src/Systems/Items/Modifiers/HealOnEventModifier.tscn")
    var inst: Node = scene.instantiate()
    inst.set("trigger_event", "on_hit")
    inst.set("default_heal", 2)
    var configured: PackedScene = ItemBuilder.pack_instance(inst)
    inst.free()
    var item: Item = ItemBuilder.make_effect_item("Heal On Event Modifier", "flavor", configured, {})
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    assert_that(lines).contains("effect: Heal On Event — Heals 2 HP (Triggers on hit)")


func test_life_leach_tooltip_shows_trigger_and_percent() -> void:
    var scene: PackedScene = load("res://src/Systems/Items/Modifiers/LifeLeachModifier.tscn")
    var item: Item = ItemBuilder.make_effect_item("life leach", "flavor", scene, {})
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    assert_that(lines).contains("effect: Life Leach — Heals 5% of dealt damage (Triggers on hit)")


func test_spinning_orbs_tooltip_shows_trigger_and_damage() -> void:
    var scene: PackedScene = load("res://src/Systems/Items/Modifiers/SpinningOrbsModifier.tscn")
    var item: Item = ItemBuilder.make_effect_item("Spinning Orbs Modifier", "flavor", scene, {})
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    assert_that(lines).contains("effect: Spinning Orbs — Orbs deal 50% of base damage (Triggers on hit)")


func test_regen_tooltip_shows_amount_without_trigger() -> void:
    var scene: PackedScene = load("res://src/Systems/Items/Modifiers/RegenModifier.tscn")
    var item: Item = ItemBuilder.make_effect_item("Regen Modifier", "flavor", scene, {})
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    # Regen is a passive timer effect: amounts shown, no trigger suffix.
    assert_that(lines).contains("effect: Regen — Regenerates 4.0 HP + 1% max HP every 0.5s")


func test_poison_tooltip_shows_trigger_and_amount() -> void:
    var scene: PackedScene = load("res://src/Systems/Items/Modifiers/PoisonModifier.tscn")
    var item: Item = ItemBuilder.make_effect_item("Poison Modifier", "flavor", scene, {})
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    assert_that(lines).contains("effect: Poison — Poison deals 100% of hit damage per tick for 3.0s (Triggers on hit)")


func _effect_line_for_scene(path: String) -> String:
    var scene: PackedScene = load(path)
    assert_object(scene).is_not_null()
    var item: Item = ItemBuilder.make_effect_item("Test Item", "flavor", scene, {})
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    for line in lines:
        if line.begins_with("effect:"):
            return line
    return ""


func test_armor_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/Modifiers/ArmorMode.tscn")).is_equal(
        "effect: Armor — Armor reduces incoming damage. (Triggers on before take damage)")


func test_bomb_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/Modifiers/bombOnHitModifier.tscn")).is_equal(
        "effect: Bomb — Attached bombs explode for 30% of hit damage after 3.0s (Triggers on hit)")


func test_chain_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/Modifiers/ChainMod.tscn")).is_equal(
        "effect: Chain — Chains to 3 extra targets (Triggers on hit)")


func test_crit_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/Modifiers/Crit.tscn")).is_equal(
        "effect: Crit — Critical hits deal extra damage based on your critical chance and multiplier. (Triggers on before deal damage)")


func test_emergency_heal_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/Modifiers/EmergencyHealModifier.tscn")).is_equal(
        "effect: Emergency Heal — Heals 75% max HP below 25% HP, 60.0s cooldown (Triggers on after take damage)")


func test_energy_shield_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/Modifiers/EnergyShield.tscn")).is_equal(
        "effect: Energy Shield — Shield absorbs damage, recharges 10.0 per second after 1.5s (Triggers on before take damage)")


func test_homing_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/Modifiers/HomingModifier.tscn")).is_equal(
        "effect: Homing — Projectiles seek targets within 400.0 (Triggers on attack)")


func test_homing_rocket_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/Modifiers/HomingRocketModifier.tscn")).is_equal(
        "effect: Homing Rocket — Launches a homing rocket dealing 100% of hit damage (Triggers on before take damage)")


func test_homing_rocket_from_target_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/Modifiers/HomingRocketFromTargetModifier.tscn")).is_equal(
        "effect: Homing Rocket From Target — Launches a homing rocket dealing 100% of hit damage (Triggers on hit)")


func test_knockback_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/Modifiers/KnockbackModifier.tscn")).is_equal(
        "effect: Knockback — Knocks back enemies with 300.0 force (Triggers on hit)")


func test_life_on_kill_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/Modifiers/LifeOnKillModifier.tscn")).is_equal(
        "effect: Life On Kill — Gain 1 max health per stack (Triggers on hit)")


func test_high_health_bonus_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/Modifiers/PlusDamageToHealthyTargetMode.tscn")).is_equal(
        "effect: High Health Bonus — Deals 30% extra damage to targets above 90% HP (Triggers on before deal damage)")


func test_reflect_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/Modifiers/ReflectProjectilesModifier.tscn")).is_equal(
        "effect: Reflect Projectiles — Fires 2 projectiles back at attackers (Triggers on before take damage)")


func test_spread_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/Modifiers/SpreadModifier.tscn")).is_equal(
        "effect: Spread — Spawn 2 extra projectiles (Triggers on attack)")


func test_stat_multiplier_tooltip() -> void:
    # No .tscn for this one: pack a script instance like the builder test does.
    var modifier: StatMultiplierModifier = preload("res://src/Systems/Items/Modifiers/stat_multiplier_modifier.gd").new()
    var packed: PackedScene = ItemBuilder.pack_instance(modifier)
    var item: Item = ItemBuilder.make_effect_item("Test Item", "flavor", packed, {})
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    assert_that(lines).contains("effect: Stat Multiplier — Multiplies damage bonuses from items by 2.0x (Triggers on item added)")
    modifier.free()


func test_every_modifier_scene_has_readable_effect_line() -> void:
    # Sweep: every effect scene in the Modifiers dir must produce exactly one
    # human-readable effect line — no blank names, no PascalCase, no doubled "on".
    var scenes: Array[PackedScene] = ItemBuilder.load_scenes_from_dir("res://src/Systems/Items/Modifiers")
    assert_bool(scenes.size() > 0).is_true()
    for scene in scenes:
        var item: Item = ItemBuilder.make_effect_item("Test Item", "flavor", scene, {})
        var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
        var effect_count := 0
        for line in lines:
            assert_bool(line.begins_with("effects:")).is_false()
            assert_bool("when triggered" in line).is_false()
            assert_bool("on on " in line).is_false()
            if line.begins_with("effect:"):
                effect_count += 1
                var head := line.trim_prefix("effect: ").strip_edges()
                assert_bool(head.is_empty()).is_false()
                assert_bool(head.begins_with("—")).is_false()
        assert_int(effect_count).is_equal(1)


func test_buff_item_tooltip_lines_via_builder() -> void:
    # Fully deterministic: buff payload + tradeoff live in known places.
    var item: Item = ItemBuilder.make_buff_item(
        "Haste Buff",
        "Grants a temporary attack speed buff",
        "attack_speed",
        {"flat": 0.1},
        load(BUFF_SCENE)
    )
    assert_object(item).is_not_null()
    assert_that(item.get_meta("type")).is_equal("buff")
    assert_int(item.effect_scene.size()).is_equal(1)

    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    assert_that(lines).contains("name: Haste Buff")
    assert_that(lines).contains("Grants a temporary attack speed buff (Triggers on hit)")
    assert_that(lines).contains("buff: attack_speed flat: 0.1")
    assert_int(lines.size()).is_equal(3)

    var buff: Buff = item.effect_scene[0].instantiate()
    assert_object(buff).is_not_null()
    assert_that(buff.modifiers).is_equal({"attack_speed": {"flat": 0.1}})
    buff.free()


func test_debuff_item_tooltip_lines_via_builder() -> void:
    # Fully deterministic: debuff payload with hardcoded values.
    var item: Item = ItemBuilder.make_debuff_item(
        "Rust Debuff",
        "Grants an armor debuff",
        "armor",
        {"flat": -10.0},
        load(DEBUFF_SCENE)
    )
    assert_object(item).is_not_null()
    assert_that(item.get_meta("type")).is_equal("debuff")
    assert_int(item.effect_scene.size()).is_equal(1)

    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    assert_that(lines).contains("name: Rust Debuff")
    assert_that(lines).contains("Grants an armor debuff (Triggers on after deal damage)")
    assert_that(lines).contains("debuff: armor flat: -10.0")
    assert_int(lines.size()).is_equal(3)

    var debuff: DebuffSource = item.effect_scene[0].instantiate()
    assert_object(debuff).is_not_null()
    assert_that(debuff.modifiers).is_equal({"armor": {"flat": -10.0}})
    debuff.free()


func test_humanize_trigger_strips_on_prefix() -> void:
    # "on_hit" must not render as "Triggers on on hit".
    assert_that(ItemTooltip.humanize_trigger("on_hit")).is_equal("hit")
    assert_that(ItemTooltip.humanize_trigger("on_crit")).is_equal("crit")
    assert_that(ItemTooltip.humanize_trigger("before_take_damage")).is_equal("before take damage")
    assert_that(ItemTooltip.humanize_trigger("after_deal_damage")).is_equal("after deal damage")


func test_effect_trigger_has_no_doubled_on() -> void:
    var scene: PackedScene = load(EFFECT_SCENE)
    var item: Item = ItemBuilder.make_effect_item("Bounce", "flavor", scene, {})
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    for line in lines:
        assert_bool("on on " in line).is_false()


func test_stale_when_triggered_flavor_is_rewritten() -> void:
    # Old factory descriptions said "when triggered" without naming the event.
    # The tooltip must resolve the packed instance's actual trigger instead.
    var item: Item = ItemBuilder.make_buff_item(
        "Haste Buff",
        "Grants a temporary buff: increases attack_speed when triggered.",
        "attack_speed",
        {"flat": 0.1},
        load(BUFF_SCENE)
    )
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    assert_that(lines).contains("Grants a temporary buff: increases attack_speed on hit.")
    for line in lines:
        assert_bool("when triggered" in line).is_false()

    var debuff_item: Item = ItemBuilder.make_debuff_item(
        "Rust Debuff",
        "Grants a debuff: decreases armor when triggered.",
        "armor",
        {"flat": -10.0},
        load(DEBUFF_SCENE)
    )
    var debuff_lines: PackedStringArray = ItemTooltip.tooltip_lines(debuff_item)
    assert_that(debuff_lines).contains("Grants a debuff: decreases armor on after deal damage.")
    for line in debuff_lines:
        assert_bool("when triggered" in line).is_false()


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

    GlobalGameState.current_character = prev_character if is_instance_valid(prev_character) else null
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


func test_freeing_character_clears_global() -> void:
    # Regression: Character._ready publishes itself to GlobalGameState.current_character.
    # It must retract that reference on free, otherwise the autoload dangles to a freed
    # instance and the restore below raises "Invalid assignment ... 'previously freed'"
    # (see test_hover_shows_and_hides_tooltip failing in full-suite runs).
    var character = load("res://src/Systems/Character.tscn").instantiate()
    add_child(character)
    assert_that(GlobalGameState.current_character).is_same(character)

    character.free()
    # Re-assigning the stale autoload value is exactly what breaks in batch runs.
    # With a live (mismatched) value this would corrupt the global, so assert null:
    GlobalGameState.current_character = GlobalGameState.current_character
    assert_that(GlobalGameState.current_character).is_null()
