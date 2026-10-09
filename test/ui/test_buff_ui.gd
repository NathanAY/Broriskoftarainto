# GdUnit TestSuite for the buff / debuff grid: two centred rows of icon tiles,
# one per live effect, with all detail hover-only.
#
# Covers both the behaviours the text prototype got wrong (debuff tiles surviving
# a character swap, the modifier-string key merging distinct buffs, a rebind
# double-subscribing) and the new ones (debuff grouping by source, the tile arc
# tracking a real countdown).
class_name BuffUiTest
extends GdUnitTestSuite

const BUFF_UI_SCENE := "res://src/ui/BuffUi.tscn"
const BUFF_SCENE := "res://src/Systems/Items/Buffs/buff.tscn"
const DEBUFF_SCENE := "res://src/Systems/Items/Buffs/DebuffSource.tscn"


## A Character-shaped entity with the children the grid and the effects look up.
## Two of these are built so `set_character()` has somewhere to move to.
func _build_character(entity_name: String) -> Character:
    var character := Character.new()
    character.name = entity_name

    var animation_player := AnimationPlayer.new()
    animation_player.name = "AnimationPlayer"
    character.add_child(animation_player)

    var hitbox := Area2D.new()
    hitbox.name = "Hitbox"
    character.add_child(hitbox)

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

    add_child(character)
    return character


## The grid on its own, subscribed to `character`. Added to the tree before the
## character is, so `set_character()` is the wiring path rather than `_ready()`'s
## parent lookup.
func _build_grid(character: Character) -> BuffUi:
    var grid: BuffUi = load(BUFF_UI_SCENE).instantiate()
    add_child(grid)
    grid.set_character(character)
    return grid


## A `Buff` effect node on `character`, built through the same scene the game's
## buff items use. `mods` is the payload the tile will render.
func _add_buff(character: Character, mods: Dictionary) -> Buff:
    var buff: Buff = load(BUFF_SCENE).instantiate()
    buff.duration = 4.0
    buff.modifiers = mods
    character.item_holder.add_child(buff)
    return buff


func _trigger(character: Character) -> void:
    character.get_node("EventManager").emit_event("on_hit", {"damage_context": DamageContext.new()})


## A `Debuff` spawned straight onto `character`, the way `DebuffSource` does it
## when an enemy lands a hit. No damage pipeline and no RNG, so the row is
## deterministic.
func _apply_debuff(character: Character, source: DebuffSource, mods: Dictionary) -> Debuff:
    var debuff := Debuff.new()
    debuff.setup(source, character, mods, 4.0, source, "Rust", "Armour is eaten away.")
    character.add_child(debuff)
    character.get_node("EventManager").emit_event("on_debuff_added", {
        "debuff": debuff,
        "holder": source.get_parent().hold_owner,
        "target": character,
    })
    return debuff


func _add_debuff_source(character: Character, mods: Dictionary) -> DebuffSource:
    var source: DebuffSource = load(DEBUFF_SCENE).instantiate()
    source.modifiers = mods
    character.item_holder.add_child(source)
    return source


func _tiles_in(row: HBoxContainer) -> Array:
    var out: Array = []
    for child in row.get_children():
        if child is BuffTile:
            out.append(child)
    return out


# --- the grid's shape -----------------------------------------------------------


func test_the_grid_is_two_centred_rows_anchored_across_the_top_of_the_screen() -> void:
    var character := _build_character("Character")
    var grid := _build_grid(character)

    # Top-wide, so `alignment = CENTER` centres each row on the screen rather
    # than on a fixed-width box. offset_top clears the HUD's 22px StageTimer
    # instead of overlapping it.
    assert_float(grid.anchor_right).is_equal(1.0)
    assert_float(grid.offset_top).override_failure_message(
        "the row must sit below the stage timer, not on top of it"
    ).is_greater_equal(22.0)
    assert_int(grid.buffs_row.alignment).is_equal(HBoxContainer.ALIGNMENT_CENTER)
    assert_int(grid.debuffs_row.alignment).is_equal(HBoxContainer.ALIGNMENT_CENTER)

    # Not wrapped in a ScrollContainer: a HUD row is not inside one, so the
    # shadow padding the gear grids need does not apply and must not be copied.
    assert_that(grid.get_node_or_null("Margin/VBox/ScrollContainer")).is_null()

    grid.free()
    character.free()


func test_the_grid_owns_its_own_tooltip() -> void:
    var character := _build_character("Character")
    var grid := _build_grid(character)

    # CharacterUI keeps its own for the gear grid; only one is ever visible,
    # because each hides on `mouse_exited`. A sibling of the rows rather than a
    # third row: it positions itself against the mouse and would otherwise be
    # laid out by the VBox and reserve vertical space it never uses.
    var tooltip: TooltipUi = grid.get_node("Tooltip")
    assert_that(tooltip).is_not_null()
    assert_that(tooltip.get_parent()).is_same(grid)
    assert_bool(tooltip.visible).override_failure_message(
        "the grid's tooltip must start hidden, like the shared one's").is_false()

    grid.free()
    character.free()


# --- buffs ---------------------------------------------------------------------


func test_buff_event_adds_one_tile_to_row_one() -> void:
    var character := _build_character("Character")
    var grid := _build_grid(character)
    _add_buff(character, {"attack_speed": {"flat": 0.5}})
    _trigger(character)

    assert_int(_tiles_in(grid.buffs_row).size()).is_equal(1)
    assert_int(_tiles_in(grid.debuffs_row).size()).is_equal(0)

    grid.free()
    character.free()


func test_two_triggers_make_one_tile_with_a_stack_badge() -> void:
    var character := _build_character("Character")
    var grid := _build_grid(character)
    _add_buff(character, {"attack_speed": {"flat": 0.5}})
    _trigger(character)
    _trigger(character)
    _trigger(character)

    var tiles := _tiles_in(grid.buffs_row)
    # One `Buff` node is one tile, and `ItemHolder._find_effect_node` already
    # collapses duplicate effect scenes into one node, so three triggers on one
    # buff are three stacks and not three tiles.
    assert_int(tiles.size()).is_equal(1)
    assert_str((tiles[0] as BuffTile).stack_badge.text).is_equal("3")
    assert_bool((tiles[0] as BuffTile).stack_badge.visible).is_true()

    grid.free()
    character.free()


func test_two_distinct_buffs_with_equal_modifiers_get_two_tiles() -> void:
    var character := _build_character("Character")
    var grid := _build_grid(character)
    _add_buff(character, {"attack_speed": {"flat": 0.5}})
    _add_buff(character, {"attack_speed": {"flat": 0.5}})
    _trigger(character)

    # Regression on the old modifier-string key: two separate buffs with the same
    # payload stringified to the same id, so the second silently folded into the
    # first and one of them was never shown.
    assert_int(_tiles_in(grid.buffs_row).size()).is_equal(2)

    grid.free()
    character.free()


func test_a_buff_whose_modifiers_change_keeps_its_tile() -> void:
    var character := _build_character("Character")
    var grid := _build_grid(character)
    var buff := _add_buff(character, {"attack_speed": {"flat": 0.5}})
    _trigger(character)
    assert_int(_tiles_in(grid.buffs_row).size()).is_equal(1)

    buff.modifiers = {"movement_speed": {"flat": 1.0}}
    _trigger(character)

    # The old key was the stringified modifier dict, so changing the payload
    # orphaned the entry and a new tile appeared beside the stale one.
    assert_int(_tiles_in(grid.buffs_row).size()).is_equal(1)
    var tile: BuffTile = _tiles_in(grid.buffs_row)[0]
    assert_str(tile.entry.resolved_name()).is_equal("Movement Speed")

    grid.free()
    character.free()


func test_removing_the_last_stack_removes_the_tile_and_leaves_no_freed_node() -> void:
    var character := _build_character("Character")
    var grid := _build_grid(character)
    var buff := _add_buff(character, {"attack_speed": {"flat": 0.5}})
    buff.duration = 0.3
    _trigger(character)
    assert_int(_tiles_in(grid.buffs_row).size()).is_equal(1)

    await get_tree().create_timer(0.5).timeout
    await get_tree().process_frame

    assert_int(_tiles_in(grid.buffs_row).size()).is_equal(0)
    for child in grid.buffs_row.get_children():
        assert_bool(is_instance_valid(child)).override_failure_message(
            "the row still holds a freed node").is_true()

    grid.free()
    character.free()


# --- debuffs --------------------------------------------------------------------


func test_debuff_event_adds_one_tile_to_row_two() -> void:
    var character := _build_character("Character")
    var grid := _build_grid(character)
    var source := _add_debuff_source(character, {"armor": {"flat": -10.0}})
    _apply_debuff(character, source, {"armor": {"flat": -10.0}})

    assert_int(_tiles_in(grid.debuffs_row).size()).is_equal(1)
    assert_int(_tiles_in(grid.buffs_row).size()).is_equal(0)

    grid.free()
    character.free()


func test_two_debuffs_from_one_source_group_and_sum() -> void:
    var character := _build_character("Character")
    var grid := _build_grid(character)
    var source := _add_debuff_source(character, {"armor": {"flat": -10.0}})
    _apply_debuff(character, source, {"armor": {"flat": -10.0}})
    _apply_debuff(character, source, {"armor": {"flat": -10.0}})

    # A debuff does not stack at its source - every trigger spawns a separate
    # `Debuff` node - so grouping on the source is what makes two curses one tile.
    var tiles := _tiles_in(grid.debuffs_row)
    assert_int(tiles.size()).is_equal(1)
    assert_str((tiles[0] as BuffTile).stack_badge.text).is_equal("2")

    grid.tooltip.show_buff((tiles[0] as BuffTile).entry)
    # The badge counts the instances and the body reports the total they moved
    # the stat by, so the two can never disagree.
    assert_str(grid.tooltip.label.text).contains("-20.0")

    grid.free()
    character.free()


func test_two_debuffs_from_different_sources_get_two_tiles() -> void:
    var character := _build_character("Character")
    var grid := _build_grid(character)
    var first := _add_debuff_source(character, {"armor": {"flat": -10.0}})
    var second := _add_debuff_source(character, {"movement_speed": {"flat": -1.0}})
    _apply_debuff(character, first, {"armor": {"flat": -10.0}})
    _apply_debuff(character, second, {"movement_speed": {"flat": -1.0}})

    assert_int(_tiles_in(grid.debuffs_row).size()).is_equal(2)

    grid.free()
    character.free()


func test_a_debuff_tile_border_is_red_where_a_buff_tile_is_green() -> void:
    var character := _build_character("Character")
    var grid := _build_grid(character)
    _add_buff(character, {"attack_speed": {"flat": 0.5}})
    _trigger(character)
    var source := _add_debuff_source(character, {"armor": {"flat": -10.0}})
    _apply_debuff(character, source, {"armor": {"flat": -10.0}})

    var buff_tile: BuffTile = _tiles_in(grid.buffs_row)[0]
    var debuff_tile: BuffTile = _tiles_in(grid.debuffs_row)[0]
    # Deliberately opposite to a shop card, where a debuff payload renders green
    # because it lands on the enemy. Here it lands on you.
    assert_bool((buff_tile.get_theme_stylebox("panel") as StyleBoxFlat).border_color
        == ItemDisplayPanel.COLOR_POSITIVE).is_true()
    assert_bool((debuff_tile.get_theme_stylebox("panel") as StyleBoxFlat).border_color
        == ItemDisplayPanel.COLOR_NEGATIVE).is_true()

    grid.free()
    character.free()


func test_debuff_timer_counts_down() -> void:
    var character := _build_character("Character")
    var grid := _build_grid(character)
    var source := _add_debuff_source(character, {"armor": {"flat": -10.0}})
    var debuff := _apply_debuff(character, source, {"armor": {"flat": -10.0}})
    debuff.duration = 4.0

    var tile: BuffTile = _tiles_in(grid.debuffs_row)[0]
    assert_bool(tile.arc.visible).override_failure_message(
        "a debuff with a running timer must draw its arc").is_true()
    var remaining_at_start: float = tile.entry.remaining
    assert_float(remaining_at_start).is_greater(0.0)

    await get_tree().create_timer(0.3).timeout
    # Re-read off the live effect node rather than off the tile: `_process()`
    # refreshes it on the next frame, which this wait has not guaranteed yet.
    var elapsed: float = debuff.remaining_time()

    # Regression on B3: the timer was parented to the *target*, so the lookup that
    # scanned the Debuff's children for it always failed and the arc sat at the
    # full duration forever.
    assert_float(elapsed).override_failure_message(
        "the arc must fall as the debuff's own timer runs: %f -> %f" % [remaining_at_start, elapsed]
    ).is_less(remaining_at_start)

    # And the tile the grid drew from that same number is not sitting at full.
    await get_tree().process_frame
    assert_float(tile.entry.arc_fraction()).is_less(1.0)

    grid.free()
    character.free()


func test_a_debuff_whose_instance_is_freed_drops_its_tile() -> void:
    var character := _build_character("Character")
    var grid := _build_grid(character)
    var source := _add_debuff_source(character, {"armor": {"flat": -10.0}})
    var debuff := _apply_debuff(character, source, {"armor": {"flat": -10.0}})
    assert_int(_tiles_in(grid.debuffs_row).size()).is_equal(1)

    # A holder freed outright takes its effects with it without emitting
    # `on_debuff_removed`, so the row has to notice on its own rather than
    # trusting the event to always arrive.
    debuff.free()
    await get_tree().process_frame
    await get_tree().process_frame

    assert_int(_tiles_in(grid.debuffs_row).size()).is_equal(0)

    grid.free()
    character.free()


# --- rows ----------------------------------------------------------------------


func test_an_empty_row_is_hidden() -> void:
    var character := _build_character("Character")
    var grid := _build_grid(character)

    # Both rows are always in the tree, so the buff row never shifts when the
    # first debuff lands - only the empty one collapses.
    assert_bool(grid.buffs_row.visible).is_false()
    assert_bool(grid.debuffs_row.visible).is_false()

    _add_buff(character, {"attack_speed": {"flat": 0.5}})
    _trigger(character)
    assert_bool(grid.buffs_row.visible).is_true()
    assert_bool(grid.debuffs_row.visible).override_failure_message(
        "a row with no tiles must reserve no gap").is_false()

    grid.free()
    character.free()


# --- the tooltip ---------------------------------------------------------------


func test_tooltip_reports_the_summed_stat_change() -> void:
    var character := _build_character("Character")
    var grid := _build_grid(character)
    _add_buff(character, {"attack_speed": {"flat": 0.5}})
    _trigger(character)
    _trigger(character)
    _trigger(character)

    var tile: BuffTile = _tiles_in(grid.buffs_row)[0]
    grid.tooltip.show_buff(tile.entry)

    # Three stacks of +0.5 read as +1.5, not +0.5. A per-stack number would
    # disagree with the stat the player is actually watching.
    assert_str(grid.tooltip.label.text).contains("+1.5")
    assert_str(grid.tooltip.label.text).contains("3 stacks (max 10)")

    grid.free()
    character.free()


func test_tooltip_names_the_trigger_and_the_stat() -> void:
    var character := _build_character("Character")
    var grid := _build_grid(character)
    _add_buff(character, {"movement_speed": {"flat": 1.0}})
    _trigger(character)

    var tile: BuffTile = _tiles_in(grid.buffs_row)[0]
    grid.tooltip.show_buff(tile.entry)

    assert_str(grid.tooltip.label.text).contains("Triggers on hit")
    # The stat's own explanation travels with the hover, so the tile never needs
    # a paragraph under it.
    assert_str(grid.tooltip.label.text).contains(ItemTooltip.stat_hint("movement_speed"))

    grid.free()
    character.free()


# --- rebinding -----------------------------------------------------------------


func test_set_character_does_not_double_subscribe() -> void:
    var character := _build_character("Character")
    var grid := _build_grid(character)
    _add_buff(character, {"attack_speed": {"flat": 0.5}})

    grid.set_character(character)
    grid.set_character(character)
    _trigger(character)

    # `set_character()` used to call `_ready()` again, which re-subscribed without
    # unsubscribing, so every listener landed twice and one trigger made two tiles.
    assert_int(_tiles_in(grid.buffs_row).size()).is_equal(1)

    grid.free()
    character.free()


func test_set_character_moves_the_grid_to_the_new_character() -> void:
    var first := _build_character("First")
    var second := _build_character("Second")
    var grid := _build_grid(first)
    _add_buff(first, {"attack_speed": {"flat": 0.5}})
    _trigger(first)
    assert_int(_tiles_in(grid.buffs_row).size()).is_equal(1)

    grid.set_character(second)

    # A character swap takes the old buffs with it, so the grid starts empty
    # rather than showing tiles for someone who is no longer there.
    assert_int(_tiles_in(grid.buffs_row).size()).is_equal(0)

    _add_buff(second, {"armor": {"flat": 3.0}})
    _trigger(second)
    assert_int(_tiles_in(grid.buffs_row).size()).is_equal(1)

    grid.free()
    first.free()
    second.free()


func test_clear_frees_both_rows() -> void:
    var character := _build_character("Character")
    var grid := _build_grid(character)
    _add_buff(character, {"attack_speed": {"flat": 0.5}})
    _trigger(character)
    var source := _add_debuff_source(character, {"armor": {"flat": -10.0}})
    _apply_debuff(character, source, {"armor": {"flat": -10.0}})
    assert_int(grid.buffs_row.get_child_count()).is_equal(1)
    assert_int(grid.debuffs_row.get_child_count()).is_equal(1)

    grid.clear()

    # Regression on B1: `_clear()` only walked the buff row, so debuff tiles
    # survived a character swap and kept hovering for the previous character.
    assert_int(grid.buffs_row.get_child_count()).is_equal(0)
    assert_int(grid.debuffs_row.get_child_count()).is_equal(0)
    assert_int(grid.active_tile_count()).is_equal(0)
    assert_bool(grid.buffs_row.visible).is_false()
    assert_bool(grid.debuffs_row.visible).is_false()

    grid.free()
    character.free()
