# GdUnit generated TestSuite
class_name ShopStageTest
extends GdUnitTestSuite


func test_shop_stage_opens_shop_automatically() -> void:
    var runner := scene_runner("res://test/TestShopStage.tscn")
    var test_scene := runner.scene()
    get_tree().current_scene = test_scene

    @warning_ignore("redundant_await")
    await runner.simulate_frames(10)

    var shop_menu: ShopMenu = test_scene.get_node("UI/ShopMenu")
    assert_bool(shop_menu.visible).is_true()
    assert_int(shop_menu.phase).is_equal(2)
    assert_bool(shop_menu.item_factory != null).is_true()
    # Shop phase generates 4 purchasable entries.
    assert_int(shop_menu.items_container.get_child_count()).is_equal(4)
    # Starting money is granted so buy/reroll work immediately.
    var character: Character = test_scene.get_node("Character")
    assert_object(GlobalGameState.current_character).is_equal(character)
    assert_float(character.get_node("Stats").stats.get("money", 0.0)).is_equal(100.0)

    get_tree().paused = false
    test_scene.free()


## A character that is built but never enters the tree, which is how the shop
## uses one. No wiring is needed: `Character`'s and the holders' refs to their
## parent resolve on access, so they work while the character is detached.
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


## Selling/taking every collected pickup must move the menu into the shop
## phase and reveal the 4 generated offers + the reroll button.
func test_resolving_all_pickups_starts_shop_phase() -> void:
    var shop: ShopMenu = load("res://src/Scenes/menu/ShopMenu.tscn").instantiate()
    add_child(shop)
    var factory: ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
    add_child(factory)
    shop.item_factory = factory

    var character := _build_character()
    character.get_node("Stats").set_base_stat("money", 20)
    shop.character = character
    GlobalGameState.current_character = character

    shop.show_menu()
    shop.load_items([factory.get_item_by_type("stat"), factory.get_item_by_type("buff")])

    # Phase 1 shows a Take/Sell card per pickup and no reroll button.
    assert_int(shop.phase).is_equal(1)
    assert_int(shop._active_item_count()).is_equal(2)
    assert_bool(shop.reroll_button.visible).is_false()

    # Resolve both pickups. Cards fade out over a tween, so they are still
    # alive as nodes here -- the shop must not count them as live offers.
    var pickup_cards: Array[ShopItemCard] = []
    for child in shop.items_container.get_children():
        if child is ShopItemCard:
            pickup_cards.append(child)
    assert_int(pickup_cards.size()).is_equal(2)
    for card in pickup_cards:
        card.secondary_button.pressed.emit()

    assert_int(shop.phase).is_equal(2)
    assert_bool(shop.reroll_button.visible).is_true()
    assert_int(shop._active_item_count()).is_equal(4)
    assert_float(character.get_node("Stats").stats.get("money", 0.0)).is_greater(20.0)

    get_tree().paused = false
    character.free()
    collect_orphan_node_details()


## Buying an offer must leave its slot empty -- the shop does not backfill
## mid-stage. Reroll is the only thing that refills the row.
func test_buying_leaves_empty_slot_until_reroll() -> void:
    var shop: ShopMenu = load("res://src/Scenes/menu/ShopMenu.tscn").instantiate()
    add_child(shop)
    var factory: ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
    add_child(factory)
    shop.item_factory = factory

    var character := _build_character()
    character.get_node("Stats").set_base_stat("money", 100)
    shop.character = character
    GlobalGameState.current_character = character

    shop.show_menu()
    shop.load_items([])
    assert_int(shop._active_item_count()).is_equal(4)

    var cards: Array[ShopItemCard] = []
    for child in shop.items_container.get_children():
        if child is ShopItemCard:
            cards.append(child)
    assert_int(cards.size()).is_equal(4)

    # Buy the first offer.
    cards[0].primary_button.pressed.emit()

    assert_int(shop._active_item_count()).is_equal(3)
    assert_int(shop._empty_slot_count()).is_equal(1)
    assert_float(character.get_node("Stats").stats.get("money", 0.0)).is_less(100.0)

    # Reroll is the only thing that tops the row back up.
    shop._on_reroll_pressed()
    assert_int(shop._active_item_count()).is_equal(4)
    assert_int(shop._empty_slot_count()).is_equal(0)

    get_tree().paused = false
    character.free()
    collect_orphan_node_details()


## Picking up pickup #2 must slide the remaining pickups left into the gap --
## phase 1 compacts, so the player never has to scroll right to see the rest.
func test_pickup_phase_compacts_left() -> void:
    var shop: ShopMenu = load("res://src/Scenes/menu/ShopMenu.tscn").instantiate()
    add_child(shop)
    var factory: ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
    add_child(factory)
    shop.item_factory = factory

    var character := _build_character()
    character.get_node("Stats").set_base_stat("money", 100)
    shop.character = character
    GlobalGameState.current_character = character

    shop.show_menu()
    shop.load_items([
        factory.get_item_by_type("stat"),
        factory.get_item_by_type("stat"),
        factory.get_item_by_type("stat"),
    ])
    assert_int(shop.phase).is_equal(1)
    assert_int(shop._active_item_count()).is_equal(3)
    assert_int(shop._empty_slot_count()).is_equal(1)
    assert_bool(shop._is_empty_slot(_live_children(shop)[3])).is_true()

    # Take the second pickup.
    var cards: Array[ShopItemCard] = []
    for child in shop.items_container.get_children():
        if child is ShopItemCard:
            cards.append(child)
    cards[1].primary_button.pressed.emit()
    await get_tree().process_frame

    # Two pickups remain, packed left; the blanks are trailing.
    var live := _live_children(shop)
    assert_int(live.size()).is_equal(4)
    assert_int(shop._active_item_count()).is_equal(2)
    assert_bool(shop._is_empty_slot(live[0])).is_false()
    assert_bool(shop._is_empty_slot(live[1])).is_false()
    assert_bool(shop._is_empty_slot(live[2])).is_true()
    assert_bool(shop._is_empty_slot(live[3])).is_true()

    get_tree().paused = false
    character.free()
    collect_orphan_node_details()


## The row always occupies SHOP_SLOT_COUNT slots: a short row is padded with
## placeholders so remaining cards keep the width they have with 4 offers.
func test_short_row_keeps_card_width() -> void:
    var shop: ShopMenu = load("res://src/Scenes/menu/ShopMenu.tscn").instantiate()
    add_child(shop)
    var factory: ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
    add_child(factory)
    shop.item_factory = factory

    var character := _build_character()
    character.get_node("Stats").set_base_stat("money", 100)
    shop.character = character
    GlobalGameState.current_character = character

    # Four pickups -> a full row of 4 real cards, no placeholders.
    shop.show_menu()
    shop.load_items([
        factory.get_item_by_type("stat"),
        factory.get_item_by_type("stat"),
        factory.get_item_by_type("stat"),
        factory.get_item_by_type("stat"),
    ])
    assert_int(shop._active_item_count()).is_equal(4)
    assert_int(shop._empty_slot_count()).is_equal(0)
    await get_tree().process_frame
    var full_row_width: float = _first_card(shop).size.x

    # One pickup -> 1 card + 3 placeholders.
    shop.load_items([factory.get_item_by_type("stat")])
    assert_int(shop.phase).is_equal(1)
    assert_int(shop._active_item_count()).is_equal(1)
    assert_int(shop._empty_slot_count()).is_equal(3)
    assert_int(_live_child_count(shop)).is_equal(4)
    await get_tree().process_frame

    # The lone card must not stretch to fill the row.
    assert_float(_first_card(shop).size.x).is_equal(full_row_width)
    # ...and the placeholders are the same width as a card.
    for child in shop.items_container.get_children():
        if not child.is_queued_for_deletion():
            assert_float(child.size.x).is_equal(full_row_width)

    get_tree().paused = false
    character.free()
    collect_orphan_node_details()


## Buying offer #2 must leave slot #2 blank: the offers to its right keep their
## positions instead of sliding left.
func test_bought_slot_keeps_its_position() -> void:
    var setup := _open_fresh_shop(100)
    var shop: ShopMenu = setup[0]
    var character: Character = setup[1]

    var names: Array[String] = []
    for child in shop.items_container.get_children():
        names.append(_card_label(shop, child))

    # Buy the second offer (index 1).
    var cards: Array[ShopItemCard] = []
    for child in shop.items_container.get_children():
        if child is ShopItemCard:
            cards.append(child)
    cards[1].primary_button.pressed.emit()
    await get_tree().process_frame

    var live := _live_children(shop)
    assert_int(live.size()).is_equal(4)
    assert_bool(shop._is_empty_slot(live[0])).is_false()
    assert_bool(shop._is_empty_slot(live[1])).is_true()
    assert_bool(shop._is_empty_slot(live[2])).is_false()
    assert_bool(shop._is_empty_slot(live[3])).is_false()
    # Offers 1, 3 and 4 are untouched and still in their original slots.
    assert_str(_card_label(shop, live[0])).is_equal(names[0])
    assert_str(_card_label(shop, live[2])).is_equal(names[2])
    assert_str(_card_label(shop, live[3])).is_equal(names[3])

    get_tree().paused = false
    character.free()
    collect_orphan_node_details()


## The placeholder is a blank panel -- no label, no text.
func test_empty_slot_has_no_text() -> void:
    var setup := _open_fresh_shop(100)
    var shop: ShopMenu = setup[0]
    var character: Character = setup[1]

    var cards: Array[ShopItemCard] = []
    for child in shop.items_container.get_children():
        if child is ShopItemCard:
            cards.append(child)
    cards[0].primary_button.pressed.emit()
    await get_tree().process_frame

    var slot: Node = _live_children(shop)[0]
    assert_bool(shop._is_empty_slot(slot)).is_true()
    assert_int(slot.get_child_count()).is_equal(0)

    get_tree().paused = false
    character.free()
    collect_orphan_node_details()


## The row is centered in its area rather than pinned to the left border.
func test_shop_row_is_centered() -> void:
    var setup := _open_fresh_shop(100)
    var shop: ShopMenu = setup[0]
    var character: Character = setup[1]
    await get_tree().process_frame

    var container: Control = shop.items_container
    var first: Control = _live_children(shop)[0]
    var last: Control = _live_children(shop)[3]

    var row_width: float = last.position.x + last.size.x - first.position.x
    var left_gap: float = first.position.x
    var right_gap: float = container.size.x - (last.position.x + last.size.x)

    # Row is narrower than the area and roughly equidistant from both edges.
    assert_float(left_gap).is_greater(0.0)
    assert_float(left_gap).is_equal_approx(right_gap, 1.0)
    assert_float(container.size.x).is_greater(row_width)

    get_tree().paused = false
    character.free()
    collect_orphan_node_details()


## Builds a shop already showing its 4 phase-2 offers.
## Returns `[shop, character]`; the caller must `free()` the character -- the
## suite must not hold a reference to it, or the orphan-node monitor walks the
## `Character <-> WeaponHolder` reference cycle forever.
func _open_fresh_shop(money: float) -> Array:
    var shop: ShopMenu = load("res://src/Scenes/menu/ShopMenu.tscn").instantiate()
    add_child(shop)
    var factory: ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
    add_child(factory)
    shop.item_factory = factory

    var character := _build_character()
    character.get_node("Stats").set_base_stat("money", money)
    shop.character = character
    GlobalGameState.current_character = character
    shop.show_menu()
    shop.load_items([])
    assert_int(shop.phase).is_equal(2)
    assert_int(shop._active_item_count()).is_equal(4)
    return [shop, character]


## Stable identity for a row child, so a test can tell slots apart. Generated
## items share names, so the unique entry id is used instead.
func _card_label(shop: ShopMenu, child: Node) -> String:
    if shop._is_empty_slot(child):
        return "<empty>"
    return str(child.get_meta("id", "?"))


func _first_card(shop: ShopMenu) -> ShopItemCard:
    for child in shop.items_container.get_children():
        if child is ShopItemCard:
            return child
    return null


func _live_child_count(shop: ShopMenu) -> int:
    var cnt := 0
    for child in shop.items_container.get_children():
        if not child.is_queued_for_deletion():
            cnt += 1
    return cnt


func _live_children(shop: ShopMenu) -> Array[Node]:
    var live: Array[Node] = []
    for child in shop.items_container.get_children():
        if not child.is_queued_for_deletion():
            live.append(child)
    return live


## Entering the portal must show the menu BEFORE harvesting pickups, otherwise
## show_menu() resets the phase that the harvest already advanced.
func test_shop_portal_opens_shop_with_no_pickups() -> void:
    var root := Node2D.new()
    root.name = "PortalTestScene"
    get_tree().root.add_child(root)
    get_tree().current_scene = root

    var ui := Node.new()
    ui.name = "UI"
    root.add_child(ui)
    var shop: ShopMenu = load("res://src/Scenes/menu/ShopMenu.tscn").instantiate()
    shop.name = "ShopMenu"
    ui.add_child(shop)
    var factory: ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
    root.add_child(factory)
    shop.item_factory = factory

    var character: Character = load("res://src/Systems/Character.tscn").instantiate()
    character.name = "Character"
    root.add_child(character)
    GlobalGameState.current_character = character

    var nodes := Node.new()
    nodes.name = "Nodes"
    root.add_child(nodes)
    var pickups := Node.new()
    pickups.name = "pickups"
    nodes.add_child(pickups)

    var portal: ShopPortal = load("res://src/Systems/ShopPortal.tscn").instantiate()
    root.add_child(portal)

    portal.default_action()

    assert_bool(shop.visible).is_true()
    assert_int(shop.phase).is_equal(2)
    assert_int(shop._active_item_count()).is_equal(4)
    assert_bool(shop.reroll_button.visible).is_true()

    get_tree().paused = false
    get_tree().current_scene = null
    root.queue_free()
    collect_orphan_node_details()

