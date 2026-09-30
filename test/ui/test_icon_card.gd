# GdUnit TestSuite for the shared IconCard tile: the compact icon + name card the
# character select grid and the character menu's Items grid are both built from.
class_name IconCardTest
extends GdUnitTestSuite

const CARD_SCENE := "res://src/ui/IconCard.tscn"
const CHARACTER_CARD_SCENE := "res://src/Scenes/menu/CharacterCard.tscn"
const CHARACTER_UI_SCENE := "res://src/ui/CharacterUI.tscn"
const SHOP_SCENE := "res://src/Scenes/menu/ShopMenu.tscn"
const SOLDIER := "res://src/Assets/character/soldier/Soldier.tres"
const PLUS_DAMAGE_ITEM := "res://src/Resources/items/PlusDamageItem.tres"
const PISTOL_WEAPON := "res://src/Resources/weapons/Pistol.tres"
const TOOLTIP_SCENE := "res://src/ui/TooltipUi.tscn"

## Every gear grid in the game, by scroll-container path. Each must pad its
## content (see the shadow test below).
const GEAR_SCROLL_PATHS := {
	CHARACTER_UI_SCENE: [
		"VBoxContainer/WeaponsAndItemsContainer/LeftContainer/LeftHBox/ItemsScroll",
		"VBoxContainer/WeaponsAndItemsContainer/LeftContainer/LeftHBox/WeaponsScroll",
	],
	SHOP_SCENE: [
		"Control/VBoxContainer/BottomContainer/ItemsContainer/ItemsScroll",
		"Control/VBoxContainer/BottomContainer/WeaponsContainer/WeaponsScroll",
	],
}


func _make_card() -> IconCard:
    var card: IconCard = load(CARD_SCENE).instantiate()
    add_child(card)
    return card


func test_tile_is_a_fixed_size_icon_and_name_card() -> void:
    var card := _make_card()
    card.set_display(load(SOLDIER))

    # Fixed size, so a grid of tiles stays aligned no matter what fills it.
    assert_vector(card.custom_minimum_size).is_equal(IconCard.CARD_SIZE)
    assert_vector(card.icon_holder.custom_minimum_size).is_equal(IconCard.PLATE_SIZE)
    # Icon above, name below - and no stat body, which is ItemDisplayPanel's job.
    assert_str(card.name_label.text).is_equal("Soldier")
    assert_int(card.name_label.horizontal_alignment).is_equal(HORIZONTAL_ALIGNMENT_CENTER)
    assert_that(card.get_node_or_null("Margin/VBox/InfoScroll")).is_null()
    assert_int(card.icon_holder.get_child_count()).is_equal(1)

    card.free()


func test_tile_uses_the_shared_panel_look() -> void:
    var card := _make_card()

    # Same background, radius and border weight as TooltipUi / ShopItemCard, so
    # a tile never reads as a bolted-on widget next to them.
    var style: StyleBoxFlat = card.get_theme_stylebox("panel")
    assert_that(style).is_not_null()
    assert_bool(style.bg_color == ItemDisplayPanel.PANEL_BG).is_true()
    assert_int(style.corner_radius_top_left).is_equal(ItemDisplayPanel.PANEL_RADIUS)
    assert_int(style.border_width_left).is_equal(2)

    card.free()


func test_tile_icon_fills_its_plate_instead_of_the_small_default() -> void:
    var card := _make_card()
    card.set_display(load(PLUS_DAMAGE_ITEM))

    # The item's icon is built at the plate size. Left at the default it would
    # be stranded in the middle of a bigger box as undersized art.
    var icon: Control = card.icon_holder.get_child(0)
    assert_vector(icon.custom_minimum_size).is_equal(IconCard.ICON_SIZE)

    card.free()


func test_tile_renders_items_and_weapons_alike() -> void:
    var card := _make_card()

    # Weapons are next to use this tile, so the shared helpers must already cover
    # them: no separate card class or hand-built icon needed.
    card.set_display(load(PISTOL_WEAPON))
    assert_str(card.name_label.text).is_equal("Pistol")
    assert_vector((card.icon_holder.get_child(0) as Control).custom_minimum_size).is_equal(IconCard.ICON_SIZE)

    card.free()


func test_redisplay_replaces_the_icon_instead_of_stacking_it() -> void:
    var card := _make_card()
    card.set_display(load(PLUS_DAMAGE_ITEM))
    card.set_display(load(PLUS_DAMAGE_ITEM))

    # A stale icon left queued for the end of the frame would stack a second one
    # on the first, so the plate must be freed immediately.
    assert_int(card.icon_holder.get_child_count()).is_equal(1)

    card.set_display(null)
    assert_int(card.icon_holder.get_child_count()).is_equal(0)
    assert_str(card.name_label.text).is_empty()

    card.free()


func test_whole_tile_is_hoverable_and_drives_the_shared_tooltip() -> void:
    var tooltip_ui = load(TOOLTIP_SCENE).instantiate()
    add_child(tooltip_ui)
    var card := _make_card()
    var item: Item = load(PLUS_DAMAGE_ITEM)
    card.set_display(item)
    tooltip_ui.bind_to_row(card, item)

    # The tile stops the mouse, and its icon is click-through so the plate
    # itself is the hover target rather than a hole in the middle of the card.
    assert_int(card.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
    assert_int((card.icon_holder.get_child(0) as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)

    assert_bool(tooltip_ui.visible).is_false()
    card.emit_signal("mouse_entered")
    assert_bool(tooltip_ui.visible).is_true()
    assert_str(tooltip_ui.name_label.text).contains("Damage Amulet")
    card.emit_signal("mouse_exited")
    assert_bool(tooltip_ui.visible).is_false()

    card.free()
    tooltip_ui.free()


func test_apply_scale_halves_the_whole_tile() -> void:
    var card: IconCard = load(CARD_SCENE).instantiate()
    card.apply_scale(0.5)
    add_child(card)
    card.set_display(load(PLUS_DAMAGE_ITEM))

    # One knob, not a second scene: card, plate, art, margins and gaps all
    # follow the factor, so a dense grid reuses the same tile.
    assert_vector(card.custom_minimum_size).is_equal(IconCard.CARD_SIZE * 0.5)
    assert_vector(card.icon_holder.custom_minimum_size).is_equal(IconCard.PLATE_SIZE * 0.5)
    assert_vector((card.icon_holder.get_child(0) as Control).custom_minimum_size).is_equal(
        IconCard.ICON_SIZE * 0.5)
    assert_int(card.margin.get_theme_constant("margin_left")).is_equal(roundi(IconCard.MARGIN * 0.5))
    assert_int(card.vbox.get_theme_constant("separation")).is_equal(roundi(IconCard.SEPARATION * 0.5))

    # The name is the exception: halving 13px would be unreadable, so it floors.
    assert_int(card.name_label.get_theme_font_size("font_size")).is_equal(IconCard.MIN_NAME_FONT_SIZE)
    # One line fits in a half-size tile; two would grow the card past its size.
    assert_int(card.name_label.max_lines_visible).is_equal(1)

    card.free()


func test_scaling_after_display_rebuilds_the_art_at_the_new_size() -> void:
    var card := _make_card()
    card.set_display(load(PLUS_DAMAGE_ITEM))
    assert_vector((card.icon_holder.get_child(0) as Control).custom_minimum_size).is_equal(
        IconCard.ICON_SIZE)

    card.apply_scale(0.5)

    # The old art is freed and rebuilt, not left at the size it was made for.
    assert_int(card.icon_holder.get_child_count()).is_equal(1)
    assert_vector((card.icon_holder.get_child(0) as Control).custom_minimum_size).is_equal(
        IconCard.ICON_SIZE * 0.5)
    assert_str(card.name_label.text).is_equal("Damage Amulet")

    card.free()


func test_every_gear_grid_pads_its_scroll_area_for_the_drop_shadow() -> void:
    # A tile draws a `shadow_size` shadow *outside* its own rect, and every gear
    # grid lives in a ScrollContainer, which clips. Without padding the first
    # row loses its top shadow and the first column its left one. ScrollContainer
    # has no content margin in 4.6, so the padding has to be a MarginContainer
    # between the scroll and the grid - that is what this guards.
    var shadow: int = (ItemDisplayPanel.make_panel_stylebox(Color.BLACK) as StyleBoxFlat).shadow_size

    for scene in [CHARACTER_UI_SCENE, SHOP_SCENE]:
        # Never added to the tree: the padding is authored on the node, so an
        # off-tree instance answers this, and adding these scenes would run their
        # `_ready()` with no character behind them.
        var root: Node = load(scene).instantiate()

        for scroll_path in GEAR_SCROLL_PATHS[scene]:
            var scroll: ScrollContainer = root.get_node(scroll_path)
            var padding := scroll.get_child(0) as MarginContainer
            assert_that(padding).is_not_null()
            assert_str(padding.name).ends_with("Margin")
            for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
                var inset: int = padding.get_theme_constant(side)
                assert_bool(inset >= shadow).is_true()
            # And the grid is inside the padding, not a sibling of it.
            assert_that(padding.get_child(0)).is_instanceof(GridContainer)

        root.free()

    var tile := _make_card()
    var card: CharacterCard = load(CHARACTER_CARD_SCENE).instantiate()
    add_child(card)

    # The character card IS a tile: same class in its ancestry, same skeleton,
    # same fixed size. A change to the tile therefore lands on both screens.
    assert_that(card is IconCard).is_true()
    assert_vector(card.custom_minimum_size).is_equal(tile.custom_minimum_size)
    for path in ["Margin", "Margin/VBox", "Margin/VBox/IconHolder", "Margin/VBox/NameLabel"]:
        var theirs: Node = card.get_node(path)
        var ours: Node = tile.get_node(path)
        assert_that(theirs).is_not_null()
        assert_that(theirs.get_class()).is_equal(ours.get_class())

    card.free()
    tile.free()
