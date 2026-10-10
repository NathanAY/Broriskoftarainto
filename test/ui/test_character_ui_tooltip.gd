# GdUnit TestSuite for the shared TooltipUi / CharacterUI / ShopMenu tooltip features
class_name CharacterUiTooltipTest
extends GdUnitTestSuite

const CHARACTER_UI_SCENE := "res://src/ui/CharacterUI.tscn"
const SHOP_SCENE := "res://src/Scenes/menu/ShopMenu.tscn"
const PISTOL_WEAPON := "res://src/Resources/weapons/Pistol.tres"
const SHOTGUN_WEAPON := "res://src/Resources/weapons/Shotgun.tres"
const DEATH_AURA := "res://src/Resources/weapons/DeathAura.tres"
const THORNS_WEAPON := "res://src/Resources/weapons/Thorns.tres"
const PLUS_DAMAGE_ITEM := "res://src/Resources/items/PlusDamageItem.tres"
const BUFF_SCENE := "res://src/Systems/Items/Buffs/buff.tscn"
const DEBUFF_SCENE := "res://src/Systems/Items/Buffs/DebuffSource.tscn"
const EFFECT_SCENE := "res://src/Systems/Items/modifiers/ProjectileBounceModifier.tscn"
const TOOLTIP_SCENE := "res://src/ui/TooltipUi.tscn"
const DETAIL_SCENE := "res://src/ui/CharacterDetailPanel.tscn"
const SOLDIER := "res://src/Assets/character/soldier/Soldier.tres"
const SOLDIER_ICON := "res://src/Assets/character/soldier/soldier_icon.png"


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
    assert_that(lines).contains("damage: 11.5")
    assert_that(lines).contains("range: 1.33 m")
    assert_that(lines).contains("attack speed: 0.8")
    # built-in modifiers declared on the pistol show as extra lines; the
    # knockback strength is authored in m/s (see docs/systems/stats.md "Units").
    assert_that(lines).contains("pierce: 2")
    assert_that(lines).contains("knockback: 0.4 m/s")
    assert_that(lines).contains("description: Pistol")
    assert_int(lines.size()).is_equal(7)


func test_shotgun_builtin_explosive_shot_line() -> void:
    var weapon: BaseWeapon = load(SHOTGUN_WEAPON)
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(weapon)
    assert_that(lines).contains("name: Shotgun")
    # The shotgun's built-in explosive shot shows as a weapon line; the damage is
    # expressed as a fraction of the hit, so the number comes from the config.
    assert_that(lines).contains("explosive shot: 20% of hit damage")


func test_area_weapon_tooltip_lines_include_description() -> void:
    var aura: BaseWeapon = load(DEATH_AURA)
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(aura)
    assert_that(lines).contains("name: DeathAura")
    assert_that(lines).contains("description: Area weapon. Hits every enemy around the wielder.")


func test_area_weapon_card_rows_include_description() -> void:
    var aura: BaseWeapon = load(DEATH_AURA)
    var rows: Array = ItemTooltip.weapon_card_rows(aura)
    var texts: Array[String] = []
    for row in rows:
        texts.append(row.text)
    assert_that(texts).contains("Area weapon. Hits every enemy around the wielder.")


func test_weapon_card_rows_are_unsigned_and_label_first() -> void:
    # A weapon's base stats belong to the weapon, not to the holder's stats, so
    # they carry no "+" (a "+" reads as a stat the player gains) and read
    # label-first like the gear rows. Attack speed is spelled as the rate
    # "0.8 attack/sec" so the bare number cannot be mistaken for a multiplier.
    var weapon: BaseWeapon = load(PISTOL_WEAPON)
    var rows: Array = ItemTooltip.weapon_card_rows(weapon)
    var displays: Array[String] = []
    for row in rows:
        var typed: ItemCardRow = row
        if typed.kind == ItemCardRow.Kind.WEAPON:
            displays.append(typed.to_display())
    assert_that(displays).contains("Damage: 11.5")
    assert_that(displays).contains("Range: 1.33 m")
    assert_that(displays).contains("Attack Speed: 0.8 attack/sec")
    assert_that(displays).contains("Pierce: 2")
    assert_that(displays).contains("Knockback: 0.4 m/s")
    for line in displays:
        assert_bool(line.begins_with("+")).override_failure_message(
            "weapon row must not be signed: %s" % line).is_false()


func _weapon_rows(resource: Resource) -> Array[String]:
    var displays: Array[String] = []
    for row in ItemTooltip.weapon_card_rows(resource):
        var typed: ItemCardRow = row
        if typed.kind == ItemCardRow.Kind.WEAPON:
            displays.append(typed.to_display())
    return displays


func test_weapon_card_rows_include_subclass_details() -> void:
    # The shotgun's pellet count is the whole point of the weapon and lives on
    # the subclass, so the card must surface it without `ItemTooltip` knowing
    # what a shotgun is.
    var shotgun: BaseWeapon = load(SHOTGUN_WEAPON)
    var rows := _weapon_rows(shotgun)
    assert_that(rows).contains("Damage: 3.5")
    assert_that(rows).contains("Attack Speed: 0.6 attack/sec")
    assert_that(rows).contains("Pellets: 5")


func test_contact_weapon_hides_the_range_row() -> void:
    # Thorns damages whatever touches the holder's hitbox, so it has no reach to
    # report and the generic Range row would be a lie.
    var thorns: BaseWeapon = load(THORNS_WEAPON)
    assert_bool(thorns.has_tooltip_range()).is_false()
    var rows := _weapon_rows(thorns)
    assert_that(rows).contains("Damage: 5")
    assert_that(rows).contains("Attack Speed: 1.6 attack/sec")
    for line in rows:
        assert_bool(line.begins_with("Range:")).override_failure_message(
            "a contact weapon must not show a Range row, got: %s" % line).is_false()


func test_base_weapon_default_detail_contract() -> void:
    var bare := BaseWeapon.new()
    assert_bool(bare.has_tooltip_range()).is_true()
    assert_array(bare.tooltip_details()).is_empty()


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


# --- characters in the shared ItemDisplayPanel ------------------------------

func test_character_icon_is_built_and_name_is_human_readable() -> void:
    var character: CharacterData = load(SOLDIER)

    # CharacterData has no `name` property, so the generic path used to fall
    # through to str(resource) and print the .tres path in the header.
    assert_str(ItemDisplayPanel.display_name(character)).is_equal("Soldier")
    assert_bool(ItemDisplayPanel.display_name(character).contains("res://")).is_false()

    # ...and the generic path built an empty Control, so the icon plate was blank.
    var icon := ItemDisplayPanel.make_icon(character)
    assert_that(icon).is_not_null()
    var found := _find_texture(icon)
    assert_that(found).is_not_null()
    assert_that(found.texture).is_equal(character.small_icon)
    icon.free()


func test_character_falls_back_to_sprite_then_placeholder() -> void:
    var sprite_only := CharacterData.new()
    sprite_only.sprite = load(SOLDIER_ICON)
    var from_sprite := ItemDisplayPanel.make_icon(sprite_only)
    assert_that(_find_texture(from_sprite).texture).is_equal(sprite_only.sprite)
    from_sprite.free()

    # Nothing assigned at all: still an icon, never an empty plate.
    var bare := CharacterData.new()
    var placeholder := ItemDisplayPanel.make_icon(bare)
    assert_that(_find_texture(placeholder)).is_not_null()
    placeholder.free()


func test_character_tooltip_renders_the_header_and_rows() -> void:
    var tooltip_ui = load(TOOLTIP_SCENE).instantiate()
    add_child(tooltip_ui)
    var character: CharacterData = load(SOLDIER)

    tooltip_ui.show_for(character)

    assert_str(tooltip_ui.name_label.text).is_equal("Soldier")
    assert_bool(tooltip_ui.type_badge.visible).is_false()
    assert_int(tooltip_ui.icon_holder.get_child_count()).is_equal(1)
    # Colored rows, not the raw "base health: 120.0" flat text.
    assert_bool(tooltip_ui.label.text.contains("Health")).is_true()
    assert_bool(tooltip_ui.label.text.contains("res://")).is_false()
    assert_bool(tooltip_ui.label.text.contains("base health:")).is_false()

    tooltip_ui.free()


func test_tooltip_and_detail_panel_share_the_same_skeleton() -> void:
    var tooltip_ui = load(TOOLTIP_SCENE).instantiate()
    add_child(tooltip_ui)
    var detail = load(DETAIL_SCENE).instantiate()
    add_child(detail)

    for node in [tooltip_ui, detail]:
        for path in ["Margin/VBox/Header/IconPlate/IconHolder", "Margin/VBox/Header/NameBox/NameLabel",
                "Margin/VBox/InfoScroll/InfoLabel"]:
            assert_that(node.get_node_or_null(path)).is_not_null()

    # Both hug their content. A zero-height scroll area is why: the panels must
    # disable scrolling for the container to report the label's real height.
    assert_int(tooltip_ui.info_scroll.vertical_scroll_mode).is_equal(ScrollContainer.SCROLL_MODE_DISABLED)
    assert_int(detail.info_scroll.vertical_scroll_mode).is_equal(ScrollContainer.SCROLL_MODE_DISABLED)
    # autowrap at width 0 breaks every word onto its own line and explodes the
    # measured height, so the label needs a wrap-width floor.
    assert_float(detail.info_label.custom_minimum_size.x).is_greater(0.0)

    tooltip_ui.free()
    detail.free()


## First TextureRect found anywhere under `node`, or null.
func _find_texture(node: Node) -> TextureRect:
    if node is TextureRect:
        return node
    for child in node.get_children():
        var found := _find_texture(child)
        if found != null:
            return found
    return null


func test_heal_on_event_tooltip_shows_trigger_and_amount() -> void:
    var scene: PackedScene = load("res://src/Systems/Items/modifiers/HealOnEventModifier.tscn")
    var item: Item = ItemBuilder.make_effect_item("Heal On Event Modifier", "flavor", scene, {})
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    # Script defaults: trigger on_crit, heal 1.
    assert_that(lines).contains("effect: Heal On Event — Heals 1 HP (Triggers on crit)")


func test_heal_on_event_tooltip_follows_configured_values() -> void:
    # Simulates factory randomization (possible_trigger_event override):
    # the tooltip must show the configured trigger + heal, not defaults.
    var scene: PackedScene = load("res://src/Systems/Items/modifiers/HealOnEventModifier.tscn")
    var inst: Node = scene.instantiate()
    inst.set("trigger_event", "on_hit")
    inst.set("default_heal", 2)
    var configured: PackedScene = ItemBuilder.pack_instance(inst)
    inst.free()
    var item: Item = ItemBuilder.make_effect_item("Heal On Event Modifier", "flavor", configured, {})
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    assert_that(lines).contains("effect: Heal On Event — Heals 2 HP (Triggers on hit)")


func test_life_leach_tooltip_shows_trigger_and_percent() -> void:
    var scene: PackedScene = load("res://src/Systems/Items/modifiers/LifeLeachModifier.tscn")
    var item: Item = ItemBuilder.make_effect_item("life leach", "flavor", scene, {})
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    assert_that(lines).contains("effect: Life Leach — Heals 5% of dealt damage per item (Triggers on hit)")


func test_spinning_orbs_tooltip_shows_trigger_and_damage() -> void:
    var scene: PackedScene = load("res://src/Systems/Items/modifiers/SpinningOrbsModifier.tscn")
    var item: Item = ItemBuilder.make_effect_item("Spinning Orbs Modifier", "flavor", scene, {})
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    assert_that(lines).contains("effect: Spinning Orbs — Orbs deal 50% of base damage (Triggers on hit)")


func test_flat_regen_tooltip_shows_amount_without_trigger() -> void:
    var scene: PackedScene = load("res://src/Systems/Items/modifiers/FlatRegenModifier.tscn")
    var item: Item = ItemBuilder.make_effect_item("Flat Regen Modifier", "flavor", scene, {})
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    # Regen is a passive timer effect: amounts shown, no trigger suffix.
    assert_that(lines).contains("effect: Flat Regen — Regenerates 4.0 HP every 0.5s")


func test_percent_regen_tooltip_shows_amount_without_trigger() -> void:
    var scene: PackedScene = load("res://src/Systems/Items/modifiers/PercentRegenModifier.tscn")
    var item: Item = ItemBuilder.make_effect_item("Percent Regen Modifier", "flavor", scene, {})
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    # Regen is a passive timer effect: amounts shown, no trigger suffix.
    assert_that(lines).contains("effect: Percent Regen — Regenerates 1% max HP every 0.5s")


func test_poison_tooltip_shows_trigger_and_amount() -> void:
    var scene: PackedScene = load("res://src/Systems/Items/modifiers/PoisonModifier.tscn")
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
    assert_that(_effect_line_for_scene("res://src/Systems/Items/modifiers/ArmorModifier.tscn")).is_equal(
        "effect: Armor — Armor reduces incoming damage. +5 armor per stack (Triggers on before take damage)")


func test_bomb_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/modifiers/BombOnHitModifier.tscn")).is_equal(
        "effect: Bomb — Attached bombs explode for 30% of hit damage after 3.0s (Triggers on hit)")


func test_chain_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/modifiers/ChainModifier.tscn")).is_equal(
        "effect: Chain — Chains to 3 extra targets per stack (Triggers on hit)")


func test_crit_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/modifiers/CritModifier.tscn")).is_equal(
        "effect: Crit — Critical hits deal extra damage based on your critical chance and multiplier. +0.15 crit multiplier per stack (Triggers on before deal damage)")


func test_emergency_heal_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/modifiers/EmergencyHealModifier.tscn")).is_equal(
        "effect: Emergency Heal — Heals 75% max HP below 25% HP, 60.0s cooldown (Triggers on after take damage)")


func test_energy_shield_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/modifiers/EnergyShieldModifier.tscn")).is_equal(
        "effect: Energy Shield — Shield absorbs damage, recharges 10.0 per second after 1.5s (+5.0 max shield per stack) (Triggers on before take damage)")


func test_explosive_shot_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/modifiers/ExplosiveShotModifier.tscn")).is_equal(
        "effect: Explosive Shot — Hits explode, dealing area damage. Explodes for 20% of hit damage (Triggers on hit)")


func test_homing_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/modifiers/HomingModifier.tscn")).is_equal(
        "effect: Homing — Projectiles seek targets within 1.33 m (Triggers on attack)")


func test_homing_rocket_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/modifiers/HomingRocketModifier.tscn")).is_equal(
        "effect: Homing Rocket — Launches a homing rocket dealing 100% of hit damage (+1 per stack) (Triggers on before take damage)")


func test_homing_rocket_from_target_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/modifiers/HomingRocketFromTargetModifier.tscn")).is_equal(
        "effect: Homing Rocket From Target — Launches a homing rocket dealing 100% of hit damage (+1 per stack) (Triggers on hit)")


func test_knockback_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/modifiers/KnockbackModifier.tscn")).is_equal(
        "effect: Knockback — Knocks back enemies at 1.0 m/s (Triggers on hit)")


func test_stat_on_kill_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/modifiers/StatOnKillModifier.tscn")).is_equal(
        "effect: Stat On Kill — Gain 1 health per stack (Triggers on kill)")


func test_stat_on_kill_tooltip_follows_configured_stat() -> void:
    # Simulates factory randomization (target_stat/add_amount override):
    # the tooltip must show the configured stat + amount, not defaults.
    var scene: PackedScene = load("res://src/Systems/Items/modifiers/StatOnKillModifier.tscn")
    var inst: Node = scene.instantiate()
    inst.set("target_stat", "damage")
    inst.set("add_amount", 2.0)
    var configured: PackedScene = ItemBuilder.pack_instance(inst)
    inst.free()
    var item: Item = ItemBuilder.make_effect_item("Stat On Kill", "flavor", configured, {})
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    assert_that(lines).contains("effect: Stat On Kill — Gain 2 damage per stack (Triggers on kill)")


func test_high_health_bonus_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/modifiers/PlusDamageToHealthyTargetModifier.tscn")).is_equal(
        "effect: High Health Bonus — Deals 30% extra damage to targets above 90% HP (Triggers on before deal damage)")


func test_reflect_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/modifiers/ReflectProjectilesModifier.tscn")).is_equal(
        "effect: Reflect Projectiles — Fires 2 projectiles back at attackers (+1 per stack) (Triggers on before take damage)")


func test_spread_tooltip() -> void:
    assert_that(_effect_line_for_scene("res://src/Systems/Items/modifiers/SpreadModifier.tscn")).is_equal(
        "effect: Spread — Spawns 2 extra projectiles per stack (Triggers on attack)")


func test_stat_multiplier_tooltip() -> void:
    # No .tscn for this one: pack a script instance like the builder test does.
    var modifier = preload("res://src/Systems/Items/modifiers/stat_multiplier_modifier.gd").new()
    var packed: PackedScene = ItemBuilder.pack_instance(modifier)
    var item: Item = ItemBuilder.make_effect_item("Test Item", "flavor", packed, {})
    var lines: PackedStringArray = ItemTooltip.tooltip_lines(item)
    assert_that(lines).contains("effect: Stat Multiplier — Multiplies damage bonuses from items by 2.0x per stack (Triggers on item added)")
    modifier.free()


func test_every_modifier_scene_has_readable_effect_line() -> void:
    # Sweep: every effect scene in the Modifiers dir must produce exactly one
    # human-readable effect line — no blank names, no PascalCase, no doubled "on".
    var scenes: Array[PackedScene] = ItemBuilder.load_scenes_from_dir("res://src/Systems/Items/modifiers")
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


func test_character_ui_items_are_laid_out_as_a_grid_table() -> void:
    var character := _build_character()
    var prev_character: Character = GlobalGameState.current_character
    GlobalGameState.current_character = character

    var ui = load(CHARACTER_UI_SCENE).instantiate()
    var item_holder: ItemHolder = character.get_node("ItemHolder")
    var items: Array[Item] = [
        load("res://src/Resources/items/ArmorPlate.tres"),
        load("res://src/Resources/items/AttackSpeedItem.tres"),
        load("res://src/Resources/items/BootsOfSpeed.tres"),
        load("res://src/Resources/items/CritGlass.tres"),
        load("res://src/Resources/items/Knockback.tres"),
        load("res://src/Resources/items/PlusDamageItem.tres"),
        load("res://src/Resources/items/PoisonHit.tres"),
    ]
    for item in items:
        item_holder.add_item(item)
    add_child(ui)
    await get_tree().process_frame
    await get_tree().process_frame

    # Same widget as the weapons area: a GridContainer, so cells fill a row and
    # wrap onto the next one instead of being stacked in a single column.
    assert_that(ui.items_container is GridContainer).is_true()
    assert_int(ui.items_container.columns).is_equal(ui.weapons_container.columns)
    assert_int(ui.items_container.get_child_count()).is_equal(items.size())

    # Every cell is the character-select tile at this screen's denser scale, so
    # a long name truncates here instead of stretching the column.
    for index in items.size():
        var cell: Control = ui.items_container.get_child(index)
        assert_that(cell is IconCard).is_true()
        assert_vector(cell.custom_minimum_size).is_equal(IconCard.CARD_SIZE * IconCard.COMPACT_SCALE)
        assert_str((cell as IconCard).name_label.text).is_equal(
            ItemDisplayPanel.display_name(items[index]))
        assert_int((cell as IconCard).icon_holder.get_child_count()).is_equal(1)

    # 7 cells in 5 columns: the first five share a row, the rest start the next.
    var first_row_y: float = (ui.items_container.get_child(0) as Control).position.y
    assert_float((ui.items_container.get_child(4) as Control).position.y).is_equal(first_row_y)
    assert_bool((ui.items_container.get_child(5) as Control).position.y > first_row_y).is_true()

    # Fixed-size tiles: a row is as wide as its tiles, not stretched by the
    # widest name in it.
    var widest: float = 0.0
    for index in 5:
        widest = maxf(widest, (ui.items_container.get_child(index) as Control).size.x)
    assert_float(widest).is_equal(IconCard.CARD_SIZE.x * IconCard.COMPACT_SCALE)

    GlobalGameState.current_character = prev_character if is_instance_valid(prev_character) else null
    ui.free()
    character.free()


func test_character_ui_weapons_use_the_same_card_as_the_items() -> void:
    var character := _build_character()
    var prev_character: Character = GlobalGameState.current_character
    GlobalGameState.current_character = character

    var ui = load(CHARACTER_UI_SCENE).instantiate()
    var weapon_holder: WeaponHolder = character.get_node("WeaponHolder")
    var weapons: Array[BaseWeapon] = [
        load("res://src/Resources/weapons/Fist.tres"),
        load("res://src/Resources/weapons/Pistol.tres"),
        load("res://src/Resources/weapons/Shotgun.tres"),
        load("res://src/Resources/weapons/DeathAura.tres"),
        load("res://src/Resources/weapons/Fist.tres"),
        load("res://src/Resources/weapons/Thorns.tres"),
    ]
    for weapon in weapons:
        weapon_holder.weapons.append(weapon)
    add_child(ui)
    await get_tree().process_frame
    await get_tree().process_frame

    assert_int(ui.weapons_container.get_child_count()).is_equal(weapons.size())

    # Same tile as the Items grid and the character select grid, at this
    # screen's denser scale.
    for index in weapons.size():
        var card: Control = ui.weapons_container.get_child(index)
        assert_that(card is IconCard).is_true()
        assert_vector(card.custom_minimum_size).is_equal(IconCard.CARD_SIZE * IconCard.COMPACT_SCALE)
        assert_str((card as IconCard).name_label.text).is_equal(
            ItemDisplayPanel.display_name(weapons[index]))
        assert_int((card as IconCard).icon_holder.get_child_count()).is_equal(1)

    # 6 tiles in 5 columns wrap onto a second row.
    var first_row_y: float = (ui.weapons_container.get_child(0) as Control).position.y
    assert_float((ui.weapons_container.get_child(4) as Control).position.y).is_equal(first_row_y)
    assert_bool((ui.weapons_container.get_child(5) as Control).position.y > first_row_y).is_true()

    # Hovering a weapon tile shows its detail in the shared tooltip.
    var hovered: Control = ui.weapons_container.get_child(1)
    hovered.emit_signal("mouse_entered")
    assert_bool(ui.tooltip.visible).is_true()
    assert_str(ui.tooltip.name_label.text).contains("Pistol")
    hovered.emit_signal("mouse_exited")
    assert_bool(ui.tooltip.visible).is_false()

    GlobalGameState.current_character = prev_character if is_instance_valid(prev_character) else null
    ui.free()
    character.free()


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
    # The name lives in the tooltip header; the body carries the stat rows.
    assert_str(ui.tooltip.name_label.text).contains("Damage Amulet")
    assert_str(ui.tooltip.label.text).contains("+5 Damage")

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
    assert_str(tooltip_ui.name_label.text).contains("Damage Amulet")
    assert_str(tooltip_ui.label.text).contains("+5 Damage")

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
    assert_str(shop.tooltip.name_label.text).contains("Damage Amulet")
    assert_str(shop.tooltip.label.text).contains("+5 Damage")
    item_row.emit_signal("mouse_exited")
    assert_bool(shop.tooltip.visible).is_false()

    # Weapons
    assert_int(shop.weapons_container.get_child_count()).is_equal(1)
    var weapon_row: Control = shop.weapons_container.get_child(0)
    weapon_row.emit_signal("mouse_entered")
    assert_bool(shop.tooltip.visible).is_true()
    assert_str(shop.tooltip.name_label.text).contains("Pistol")
    # Weapon stats are label-first and unsigned in the card/tooltip body.
    assert_str(shop.tooltip.label.text).contains("Range: 1.33 m")
    assert_str(shop.tooltip.label.text).contains("Attack Speed: 0.8 attack/sec")
    weapon_row.emit_signal("mouse_exited")
    assert_bool(shop.tooltip.visible).is_false()

    shop.free()
    character.free()


func test_stat_hint_flat_weapon_damage_mentions_fast_attacking() -> void:
    var hint: String = ItemTooltip.stat_hint("flat_weapon_damage")
    assert_bool(hint.is_empty()).is_false()
    assert_that(hint).contains("fast-attacking weapons with low base damage")


func test_stat_hint_armor_has_formula_and_examples() -> void:
    var hint: String = ItemTooltip.stat_hint("armor")
    assert_bool(hint.is_empty()).is_false()
    assert_that(hint).contains("(10 / (10 + armor))")
    assert_that(hint).contains("1 armor blocks about 9%")
    assert_that(hint).contains("10 armor blocks 50%")


func test_tooltip_ui_bind_to_row_text() -> void:
    var tooltip_ui = load("res://src/ui/TooltipUi.tscn").instantiate()
    add_child(tooltip_ui)

    var row: Control = HBoxContainer.new()
    row.add_child(Label.new())
    add_child(row)

    tooltip_ui.bind_to_row_text(row, "some hint")
    assert_bool(tooltip_ui.visible).is_false()

    row.emit_signal("mouse_entered")
    assert_bool(tooltip_ui.visible).is_true()
    assert_str(tooltip_ui.label.text).contains("some hint")

    row.emit_signal("mouse_exited")
    assert_bool(tooltip_ui.visible).is_false()

    row.free()
    tooltip_ui.free()


func test_tooltip_body_hugs_its_content() -> void:
    # A ScrollContainer reports zero minimum height on a scrolling axis, which
    # would collapse a self-sizing tooltip. Disabling scroll and giving the
    # label a definite wrap width is what keeps the body visible.
    var tooltip_ui = load("res://src/ui/TooltipUi.tscn").instantiate()
    add_child(tooltip_ui)
    tooltip_ui.show_for(load(PLUS_DAMAGE_ITEM))

    assert_int(tooltip_ui.info_scroll.vertical_scroll_mode).is_equal(ScrollContainer.SCROLL_MODE_DISABLED)
    assert_int(tooltip_ui.info_scroll.horizontal_scroll_mode).is_equal(ScrollContainer.SCROLL_MODE_DISABLED)
    # A zero width would make autowrap break every word onto its own line,
    # inflating the measured height.
    assert_float(tooltip_ui.info_label.custom_minimum_size.x).is_greater(0.0)
    # The scroll area and the panel must both report a real height, otherwise
    # the body collapses to nothing and nothing is drawn.
    assert_float(tooltip_ui.info_scroll.get_minimum_size().y).is_greater(0.0)
    assert_float(tooltip_ui.get_combined_minimum_size().y).is_greater(0.0)

    tooltip_ui.free()


func test_tooltip_hides_header_chrome_for_text_hints() -> void:
    var tooltip_ui = load("res://src/ui/TooltipUi.tscn").instantiate()
    add_child(tooltip_ui)

    tooltip_ui.show_for(load(PLUS_DAMAGE_ITEM))
    assert_bool(tooltip_ui.icon_plate.visible).is_true()
    assert_bool(tooltip_ui.separator.visible).is_true()

    # No icon given: the plate is collapsed instead of leaving an empty strip
    # above the text.
    tooltip_ui.show_text("just a hint")
    assert_bool(tooltip_ui.icon_plate.visible).is_false()
    assert_bool(tooltip_ui.separator.visible).is_false()
    assert_str(tooltip_ui.name_label.text).is_empty()

    # Going back to a resource restores the header.
    tooltip_ui.show_for(load(PLUS_DAMAGE_ITEM))
    assert_bool(tooltip_ui.icon_plate.visible).is_true()
    assert_bool(tooltip_ui.separator.visible).is_true()

    tooltip_ui.free()


# --- shared ItemDisplayPanel ------------------------------------------------

func test_tooltip_and_card_share_the_same_base() -> void:
    # Both are the same widget at two scales, so the shared rendering lives in
    # one place instead of being copy-pasted.
    var tooltip_ui = load("res://src/ui/TooltipUi.tscn").instantiate()
    add_child(tooltip_ui)
    var card = load("res://src/Scenes/menu/ShopItemCard.tscn").instantiate()
    add_child(card)

    assert_that(tooltip_ui is ItemDisplayPanel).is_true()
    assert_that(card is ItemDisplayPanel).is_true()
    assert_that(card is TooltipUi).is_false()

    # Same node skeleton, so the header/body slots resolve identically.
    for panel in [tooltip_ui, card]:
        assert_that(panel.get_node("Margin/VBox/Header/IconPlate/IconHolder")).is_not_null()
        assert_that(panel.get_node("Margin/VBox/InfoScroll/InfoLabel")).is_not_null()
        assert_that(panel.name_label).is_same(panel.get_node("Margin/VBox/Header/NameBox/NameLabel"))

    tooltip_ui.free()
    card.free()


func test_tooltip_is_smaller_than_card() -> void:
    var tooltip_ui = load("res://src/ui/TooltipUi.tscn").instantiate()
    add_child(tooltip_ui)
    var card = load("res://src/Scenes/menu/ShopItemCard.tscn").instantiate()
    add_child(card)

    assert_bool(tooltip_ui.custom_minimum_size.x < card.custom_minimum_size.x).is_true()
    var tip_icon: Vector2 = tooltip_ui.get_node("Margin/VBox/Header/IconPlate").custom_minimum_size
    var card_icon: Vector2 = card.get_node("Margin/VBox/Header/IconPlate").custom_minimum_size
    assert_bool(tip_icon.x < card_icon.x).is_true()

    # Body text is set at a smaller font size too.
    assert_int(tooltip_ui.info_label.get_theme_font_size("normal_font_size")).is_less(
        card.info_label.get_theme_font_size("normal_font_size"))

    tooltip_ui.free()
    card.free()


func test_tooltip_renders_item_with_header_and_toned_body() -> void:
    var tooltip_ui = load("res://src/ui/TooltipUi.tscn").instantiate()
    add_child(tooltip_ui)

    var item: Item = load("res://src/Resources/items/ProjSlow.tres")
    tooltip_ui.show_for(item)

    # Name in the header, raw id humanized; stat rows in the body.
    assert_str(tooltip_ui.name_label.text).is_equal("Proj Slow")
    assert_bool(tooltip_ui.is_weapon).is_false()
    assert_str(tooltip_ui.label.text).contains("-0.5 Projectile Speed Multiplier")
    assert_str(tooltip_ui.label.text).contains(ItemDisplayPanel.COLOR_NEGATIVE.to_html(false))
    # Negative stat, so no name line repeated in the body.
    assert_bool(tooltip_ui.label.text.contains("Proj Slow")).is_false()

    tooltip_ui.free()


func test_tooltip_marks_weapons_with_badge() -> void:
    var tooltip_ui = load("res://src/ui/TooltipUi.tscn").instantiate()
    add_child(tooltip_ui)

    var weapon: BaseWeapon = load(PISTOL_WEAPON)
    tooltip_ui.show_for(weapon)

    assert_bool(tooltip_ui.is_weapon).is_true()
    assert_bool(tooltip_ui.type_badge.visible).is_true()
    assert_str(tooltip_ui.name_label.text).is_equal("Pistol")

    tooltip_ui.free()


func test_tooltip_icon_is_replaced_not_stacked() -> void:
    var tooltip_ui = load("res://src/ui/TooltipUi.tscn").instantiate()
    add_child(tooltip_ui)
    tooltip_ui.show_for(load(PLUS_DAMAGE_ITEM))
    assert_int(tooltip_ui.icon_holder.get_child_count()).is_equal(1)

    # Zero, not one: the old icon is detached immediately rather than left in
    # the tree until the end of the frame.
    tooltip_ui.show_text("just a hint")
    assert_int(tooltip_ui.icon_holder.get_child_count()).is_equal(0)
    assert_str(tooltip_ui.name_label.text).is_empty()
    assert_bool(tooltip_ui.type_badge.visible).is_false()
    assert_str(tooltip_ui.label.text).contains("just a hint")

    # A second hint must not stack a second icon on the first.
    tooltip_ui.show_text("another hint", Stats.get_stat_icon("damage"))
    assert_int(tooltip_ui.icon_holder.get_child_count()).is_equal(1)

    tooltip_ui.free()


func test_tooltip_text_hint_shows_stat_icon() -> void:
    var tooltip_ui = load("res://src/ui/TooltipUi.tscn").instantiate()
    add_child(tooltip_ui)

    # A stat hint passes its own icon, so the plate is filled instead of leaving
    # an empty strip above the text.
    var icon: Texture2D = Stats.get_stat_icon("health")
    assert_object(icon).is_not_null()
    tooltip_ui.show_text(ItemTooltip.stat_hint("health"), icon)

    assert_bool(tooltip_ui.icon_plate.visible).is_true()
    assert_int(tooltip_ui.icon_holder.get_child_count()).is_equal(1)
    var icon_rect: TextureRect = _find_texture_rect(tooltip_ui.icon_holder)
    assert_object(icon_rect).is_not_null()
    assert_object(icon_rect.texture).is_same(icon)
    # Sized to the tooltip plate, not the card's 48px item icon.
    assert_vector(icon_rect.get_parent().custom_minimum_size).is_equal(TooltipUi.HINT_ICON_SIZE)
    # Still a plain hint: no name, no badge, prose body.
    assert_str(tooltip_ui.name_label.text).is_empty()
    assert_bool(tooltip_ui.type_badge.visible).is_false()
    assert_bool(tooltip_ui.separator.visible).is_false()
    assert_str(tooltip_ui.label.text).contains(ItemTooltip.stat_hint("health"))

    tooltip_ui.free()


func _find_texture_rect(node: Node) -> TextureRect:
    if node is TextureRect:
        return node
    for child in node.get_children():
        var found: TextureRect = _find_texture_rect(child)
        if found != null:
            return found
    return null


func test_item_display_panel_build_bbcode_skips_name_and_colors_tones() -> void:
    var item: Item = load(PLUS_DAMAGE_ITEM)
    var rows: Array = ItemTooltip.card_rows(item)
    var bbcode := ItemDisplayPanel.build_bbcode(rows, item)

    # The name row is dropped because it lives in the header.
    assert_bool(bbcode.contains("Damage Amulet")).is_false()
    assert_str(bbcode).contains("+5 Damage")
    assert_str(bbcode).contains(ItemDisplayPanel.COLOR_POSITIVE.to_html(false))


func test_item_display_panel_falls_back_to_plain_lines() -> void:
    # CharacterData has no card_rows(), so the body must still render.
    var character: CharacterData = CharacterData.new()
    character.display_name = "Brawler"
    var bbcode := ItemDisplayPanel.build_bbcode(ItemTooltip.card_rows(character), character)
    assert_str(bbcode).contains("name: Brawler")


func test_item_display_panel_make_icon_handles_item_and_weapon() -> void:
    var item_icon := ItemDisplayPanel.make_icon(load(PLUS_DAMAGE_ITEM))
    assert_that(item_icon).is_not_null()

    # A weapon with no sprite must fall back to the default, not crash.
    var bare := BaseWeapon.new()
    bare.name = "Bare"
    var weapon_icon := ItemDisplayPanel.make_icon(bare)
    assert_that(weapon_icon).is_not_null()

    # Unknown resource kinds return an empty holder rather than null.
    var other_icon := ItemDisplayPanel.make_icon(CharacterData.new())
    assert_that(other_icon).is_not_null()

    item_icon.free()
    weapon_icon.free()
    other_icon.free()


func test_character_ui_stat_rows_have_tooltips() -> void:
    var character := _build_character()
    var prev_character: Character = GlobalGameState.current_character
    GlobalGameState.current_character = character

    var ui = load(CHARACTER_UI_SCENE).instantiate()
    add_child(ui)

    assert_int(ui.stats_container.get_child_count()).is_greater(0)
    var row: Control = ui.stats_container.get_child(0)
    # The row and the tooltip show the same stat icon, so hovering never leaves
    # an empty strip above the hint.
    var stat_name: String = str((row.get_child(1) as Label).name).replace("value_", "")
    var expected: Texture2D = Stats.get_stat_icon(stat_name)
    assert_object((row.get_child(0) as TextureRect).texture).is_same(expected)

    row.emit_signal("mouse_entered")
    assert_bool(ui.tooltip.visible).is_true()
    assert_bool(ui.tooltip.label.text.is_empty()).is_false()
    assert_bool(ui.tooltip.icon_plate.visible).is_true()
    var icon_rect: TextureRect = _find_texture_rect(ui.tooltip.icon_holder)
    assert_object(icon_rect).is_not_null()
    assert_object(icon_rect.texture).is_same(expected)
    row.emit_signal("mouse_exited")
    assert_bool(ui.tooltip.visible).is_false()

    GlobalGameState.current_character = prev_character if is_instance_valid(prev_character) else null
    ui.free()
    character.free()


func test_shop_menu_stat_rows_have_tooltips() -> void:
    var character := _build_character()

    var shop = load(SHOP_SCENE).instantiate()
    add_child(shop)
    shop.character = character
    shop._update_stats()

    assert_int(shop.stats_container.get_child_count()).is_greater(0)
    var row: Control = shop.stats_container.get_child(0)
    var stat_name: String = str((row.get_child(1) as Label).name).replace("value_", "")
    var expected: Texture2D = Stats.get_stat_icon(stat_name)
    row.emit_signal("mouse_entered")
    assert_bool(shop.tooltip.visible).is_true()
    assert_bool(shop.tooltip.label.text.is_empty()).is_false()
    assert_bool(shop.tooltip.icon_plate.visible).is_true()
    var icon_rect: TextureRect = _find_texture_rect(shop.tooltip.icon_holder)
    assert_object(icon_rect).is_not_null()
    assert_object(icon_rect.texture).is_same(expected)
    row.emit_signal("mouse_exited")
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
