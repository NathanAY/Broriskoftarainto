extends CanvasLayer

signal closed

const WEAPONS_PATH := "res://Resources/weapons"
const ITEMS_PATH := "res://Resources/items"
const EFFECTS_PATH := "res://Systems/Items/Modifiers"
const BUFF_PATH := "res://Systems/Items/Buffs/buff.tscn"
const DEBUFF_PATH := "res://Systems/Items/Buffs/DebuffSource.tscn"

var stats_ref: Stats = Stats.new()

func _find_stats_node() -> Stats:
    var root = get_tree().get_root()
    var stack := [root]
    while stack.size() > 0:
        var node = stack.pop_back()
        if node is Stats:
            return node
        for child in node.get_children():
            stack.append(child)
    return null

func _ready():
    # Connect button signals
    $Control/VBoxContainer/Footer/Close.pressed.connect(func(): _on_close_pressed())
    $Control/VBoxContainer/Footer/CreateSimpleItem.pressed.connect(func(): _create_simple_item())
    $Control/VBoxContainer/Footer/ClearAll.pressed.connect(func(): _clear_all())

    # Populate UI from scene nodes
    var available_weapons = $Control/VBoxContainer/WeaponsAndItemsContainer/WeaponsContainer/WeaponsHBox/AvailableWeaponsScroll/AvailableWeaponsList
    var equipped_weapons = $Control/VBoxContainer/WeaponsAndItemsContainer/WeaponsContainer/WeaponsHBox/EquippedWeaponsScroll/EquippedWeaponsList
    var available_items = $Control/VBoxContainer/WeaponsAndItemsContainer/ItemsContainer/ItemsHBox/AvailableItemsScroll/AvailableItemsList
    var equipped_items = $Control/VBoxContainer/WeaponsAndItemsContainer/ItemsContainer/ItemsHBox/EquippedItemsScroll/EquippedItemsList

    # Setup weapon UI
    _populate_available_weapons(available_weapons, equipped_weapons)
    _refresh_equipped_list(equipped_weapons)

    # Setup item creator UI from scene
    var stat_select = $Control/VBoxContainer/WeaponsAndItemsContainer/ItemsContainer/ItemsHBox/AvailableItemsScroll/AvailableItemsList/StatCreatorBox/StatSelect
    var stat_value = $Control/VBoxContainer/WeaponsAndItemsContainer/ItemsContainer/ItemsHBox/AvailableItemsScroll/AvailableItemsList/StatCreatorBox/StatValue
    var stat_btn = $Control/VBoxContainer/WeaponsAndItemsContainer/ItemsContainer/ItemsHBox/AvailableItemsScroll/AvailableItemsList/StatCreatorBox/StatAddButton
    
    var buff_select = $Control/VBoxContainer/WeaponsAndItemsContainer/ItemsContainer/ItemsHBox/AvailableItemsScroll/AvailableItemsList/BuffCreatorBox/BuffSelect
    var buff_value = $Control/VBoxContainer/WeaponsAndItemsContainer/ItemsContainer/ItemsHBox/AvailableItemsScroll/AvailableItemsList/BuffCreatorBox/BuffValue
    var buff_btn = $Control/VBoxContainer/WeaponsAndItemsContainer/ItemsContainer/ItemsHBox/AvailableItemsScroll/AvailableItemsList/BuffCreatorBox/BuffAddButton
    
    var debuff_select = $Control/VBoxContainer/WeaponsAndItemsContainer/ItemsContainer/ItemsHBox/AvailableItemsScroll/AvailableItemsList/DebuffCreatorBox/DebuffSelect
    var debuff_value = $Control/VBoxContainer/WeaponsAndItemsContainer/ItemsContainer/ItemsHBox/AvailableItemsScroll/AvailableItemsList/DebuffCreatorBox/DebuffValue
    var debuff_btn = $Control/VBoxContainer/WeaponsAndItemsContainer/ItemsContainer/ItemsHBox/AvailableItemsScroll/AvailableItemsList/DebuffCreatorBox/DebuffAddButton
    
    var effect_list = $Control/VBoxContainer/WeaponsAndItemsContainer/ItemsContainer/ItemsHBox/AvailableItemsScroll/AvailableItemsList/EffectList

    # Populate stat selectors and connect buttons
    for s in stats_ref.stats.keys():
        stat_select.add_item(s)
        buff_select.add_item(s)
        debuff_select.add_item(s)
    
    stat_btn.pressed.connect(func(s=stat_select, v=stat_value, rc=equipped_items):
        _create_stat_item(s.get_item_text(s.get_selected_id()), v.value, rc))
    
    buff_btn.pressed.connect(func(s=buff_select, v=buff_value, rc=equipped_items):
        _create_buff_item(s.get_item_text(s.get_selected_id()), v.value, rc))
    
    debuff_btn.pressed.connect(func(s=debuff_select, v=debuff_value, rc=equipped_items):
        _create_debuff_item(s.get_item_text(s.get_selected_id()), v.value, rc))

    # Load effect modifiers and create buttons
    _populate_effect_items(effect_list, equipped_items)
    _refresh_equipped_items(equipped_items)

func _get_player():
    var chars = get_tree().get_nodes_in_group("character")
    if chars.size() > 0:
        return chars[0]
    return null

func _populate_available_weapons(container: VBoxContainer, cur_container: VBoxContainer) -> void:
    var dir := DirAccess.open(WEAPONS_PATH)
    if not dir:
        push_warning("ConfigurePanel: cannot open " + WEAPONS_PATH)
        return
    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
        if not dir.current_is_dir() and file_name.ends_with(".tres"):
            var path = WEAPONS_PATH + "/" + file_name
            var display_name := file_name.get_basename()
            var btn = Button.new()
            btn.text = "Add " + display_name
            btn.pressed.connect(func(p=path): _on_add_weapon(p, container, cur_container))
            container.add_child(btn)
        file_name = dir.get_next()
    dir.list_dir_end()

func _populate_effect_items(container: VBoxContainer, result_container: VBoxContainer) -> void:
    var dir := DirAccess.open(EFFECTS_PATH)
    if not dir:
        push_warning("ConfigurePanel: cannot open " + EFFECTS_PATH)
        return
    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
        if not dir.current_is_dir() and file_name.ends_with(".tscn"):
            var path = EFFECTS_PATH + "/" + file_name
            var display_name := file_name.get_basename()
            var btn = Button.new()
            btn.text = "Add " + display_name
            btn.pressed.connect(func(p=path, rc=result_container): _create_effect_item(p, rc))
            container.add_child(btn)
        file_name = dir.get_next()
    dir.list_dir_end()

func _on_add_weapon(path: String, _avail_container: VBoxContainer, cur_container: VBoxContainer) -> void:
    var player = _get_player()
    if player and player.has_node("WeaponHolder"):
        var wh = player.get_node("WeaponHolder")
        wh.add_weapon(load(path))
        _refresh_equipped_list(cur_container)
    else:
        # fallback: add to GlobalGameState for next run
        if Engine.has_singleton("GlobalGameState"):
            GlobalGameState.starting_weapons.append(path)
        else:
            push_warning("No player found and no GlobalGameState autoload")

func _on_add_modifier_item(path: String) -> void:
    var player = _get_player()
    if player and player.has_node("ItemHolder"):
        var ih = player.get_node("ItemHolder")
        ih.add_item(load(path))
        # refresh UI if using scene layout
        if has_node("Control"):
            var items_cur = $Control/VBoxContainer/WeaponsAndItemsContainer/ItemsContainer/ItemsHBox/EquippedItemsScroll/EquippedItemsList
            _refresh_equipped_items(items_cur)
    else:
        if Engine.has_singleton("GlobalGameState"):
            GlobalGameState.starting_items.append(path)
        else:
            push_warning("No player found and no GlobalGameState autoload")

func _create_effect_item(effect_scene_path: String, result_container: VBoxContainer=null) -> void:
    var effect_scene: PackedScene = load(effect_scene_path)
    if not effect_scene:
        push_warning("Could not load effect scene: " + effect_scene_path)
        return
    
    var item := Item.new()
    var effect_name = effect_scene_path.get_file().get_basename()
    item.name = "Effect: " + effect_name
    item.description = "Grants effect: " + effect_name
    item.effect_scene = [effect_scene]

    var player = _get_player()
    if player and player.has_node("ItemHolder"):
        var ih = player.get_node("ItemHolder")
        ih.add_item(item)
        if result_container:
            _refresh_equipped_items(result_container)
    else:
        push_warning("No player present to receive effect item")

func _create_buff_item(stat_name: String, amount: float, result_container: VBoxContainer=null) -> void:
    var buff_scene: PackedScene = load(BUFF_PATH)
    if not buff_scene:
        push_warning("Could not load buff scene: " + BUFF_PATH)
        return
    
    var item := Item.new()
    item.name = "Buff_%s_%s" % [stat_name, str(amount)]
    item.description = "Buff: +%s %s" % [amount, stat_name]
    item.effect_scene = [buff_scene]
    item.set_meta("type", "buff")
    
    # Store modifier info for the buff
    item.modifiers = {stat_name: {"flat": amount}}

    var player = _get_player()
    if player and player.has_node("ItemHolder"):
        var ih = player.get_node("ItemHolder")
        ih.add_item(item)
        if result_container:
            _refresh_equipped_items(result_container)
    else:
        push_warning("No player present to receive buff item")

func _create_debuff_item(stat_name: String, amount: float, result_container: VBoxContainer=null) -> void:
    var debuff_scene: PackedScene = load(DEBUFF_PATH)
    if not debuff_scene:
        push_warning("Could not load debuff scene: " + DEBUFF_PATH)
        return
    
    var item := Item.new()
    item.name = "Debuff_%s_%s" % [stat_name, str(amount)]
    item.description = "Debuff: -%s %s" % [amount, stat_name]
    item.effect_scene = [debuff_scene]
    item.set_meta("type", "debuff")
    
    # Store modifier info for the debuff (negative)
    item.modifiers = {stat_name: {"flat": -amount}}

    var player = _get_player()
    if player and player.has_node("ItemHolder"):
        var ih = player.get_node("ItemHolder")
        ih.add_item(item)
        if result_container:
            _refresh_equipped_items(result_container)
    else:
        push_warning("No player present to receive debuff item")

func _create_stat_item(stat_name: String, amount: float, result_container: VBoxContainer=null) -> void:
    var item := Item.new()
    item.name = "Debug_%s_%s" % [stat_name, str(amount)]
    item.description = "%s %s (debug)" % [stat_name, amount]
    item.modifiers = {stat_name: {"flat": amount}}

    var player = _get_player()
    if player and player.has_node("ItemHolder"):
        var ih = player.get_node("ItemHolder")
        ih.add_item(item)
        if result_container:
            _refresh_equipped_items(result_container)
    else:
        push_warning("No player present to receive stat item (items are runtime-only)")

func _refresh_equipped_list(container: VBoxContainer) -> void:
    # Clear old children
    for child in container.get_children():
        child.queue_free()
    var player = _get_player()
    if not player or not player.has_node("WeaponHolder"):
        var label := Label.new()
        label.text = "(No player in scene)"
        container.add_child(label)
        return
    var wh = player.get_node("WeaponHolder")
    for w in wh.weapons:
        var weapon_name := "Weapon"
        if w is Resource and w.get("name") != null:
            weapon_name = w.get("name")
        var h := HBoxContainer.new()
        var lbl := Label.new()
        lbl.text = weapon_name
        h.add_child(lbl)
        var rem := Button.new()
        rem.text = "Remove"
        rem.pressed.connect(func(wref=w, curc=container): _on_remove_weapon(wref, curc))
        h.add_child(rem)
        container.add_child(h)

func _on_remove_weapon(weapon_inst, container: VBoxContainer) -> void:
    var player = _get_player()
    if player and player.has_node("WeaponHolder"):
        var wh = player.get_node("WeaponHolder")
        wh.remove_weapon(weapon_inst)
        _refresh_equipped_list(container)

func _refresh_equipped_items(container: VBoxContainer) -> void:
    # clear
    for c in container.get_children():
        c.queue_free()
    var player = _get_player()
    if not player or not player.has_node("ItemHolder"):
        var label := Label.new()
        label.text = "(No player in scene)"
        container.add_child(label)
        return
    var ih = player.get_node("ItemHolder")
    for it in ih.items:
        var item_name := "Item"
        if it is Resource and it.get("name") != null:
            item_name = it.get("name")
        var h := HBoxContainer.new()
        var lbl := Label.new()
        lbl.text = item_name
        h.add_child(lbl)
        var rem := Button.new()
        rem.text = "Remove"
        rem.pressed.connect(func(iref=it, curc=container): _on_remove_item(iref, curc))
        h.add_child(rem)
        container.add_child(h)

func _on_remove_item(item_inst, container: VBoxContainer) -> void:
    var player = _get_player()
    if player and player.has_node("ItemHolder"):
        var ih = player.get_node("ItemHolder")
        ih.remove_item(item_inst)
        _refresh_equipped_items(container)

func _create_simple_item() -> void:
    # Create a tiny Item resource with one modifier and add it to the player's ItemHolder
    var item := Item.new()
    item.name = "Debug Simple Item"
    item.description = "+5 damage (debug)"
    item.modifiers = {"damage": {"flat": 5}}
    var player = _get_player()
    if player and player.has_node("ItemHolder"):
        var ih = player.get_node("ItemHolder")
        ih.add_item(item)
        # refresh UI
        if has_node("Control"):
            var items_cur = $Control/VBoxContainer/WeaponsAndItemsContainer/ItemsContainer/ItemsHBox/EquippedItemsScroll/EquippedItemsList
            _refresh_equipped_items(items_cur)
    else:
        push_warning("No player present to receive simple item")

func _on_close_pressed():
    visible = false
    emit_signal("closed")

func _clear_all():
    var player = _get_player()
    if player:
        if player.has_node("WeaponHolder"):
            var wh = player.get_node("WeaponHolder")
            # iterate over a copy to avoid mutation while removing
            var weapons_copy = []
            for w in wh.weapons:
                weapons_copy.append(w)
            for wref in weapons_copy:
                wh.remove_weapon(wref)
        if player.has_node("ItemHolder"):
            var ih = player.get_node("ItemHolder")
            var items_copy = []
            for it in ih.items:
                items_copy.append(it)
            for iref in items_copy:
                ih.remove_item(iref)
    else:
        push_warning("ConfigurePanel: no player present to clear")

    # If there's a GlobalGameState autoload, clear starting lists so next run is clean
    if Engine.has_singleton("GlobalGameState"):
        GlobalGameState.starting_weapons = []
        GlobalGameState.starting_items = []
