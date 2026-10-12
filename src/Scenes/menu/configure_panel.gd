extends CanvasLayer

signal closed

const WEAPONS_PATH := "res://src/Resources/weapons"
const ITEMS_PATH := "res://src/Resources/items"
const EFFECTS_PATH := "res://src/Systems/Items/modifiers"
const BUFF_PATH := "res://src/Systems/Items/Buffs/buff.tscn"
const DEBUFF_PATH := "res://src/Systems/Items/Buffs/DebuffSource.tscn"

## The stat names the item creators offer. Read off the class, not off an
## instance: `Stats.new()` is a `Node`, so holding one as a script-scope field
## leaks an orphan for the life of the process, and all it was ever used for was
## its key list.
func _stat_names() -> Array:
    return Stats.DEFAULT_STATS.keys()

## The entity this panel is editing. Null means the player, which is what the
## panel has always done.
##
## Set before the node enters the tree - `_ready()` reads it while populating the
## equipped lists, so anything set later would show the player's gear for a panel
## that is about to edit an enemy.
## Set to true by the setter, and never cleared.
##
## It has to be separate from `target_entity` because a freed object compares
## equal to `null` in Godot 4, so `target_entity != null` cannot tell "never
## pointed at anything" from "pointed at an enemy that has since died" - it is
## false for both. That distinction is the whole behaviour: the first means "this
## is the player's panel", the second means "its target is gone".
var _was_pointed_at := false

var target_entity: Node = null:
    set(value):
        # Assigning null is not "pointed at", it is the untouched default - the
        # pause menu never assigns null, and a caller that does means "the player".
        if value == null:
            return
        target_entity = value
        _was_pointed_at = true
        # Repointed after the panel is up, so the title follows. Before tree entry
        # there is nothing to repaint and `_ready()` does it instead.
        if is_inside_tree():
            _refresh_title()

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
    var _available_items = $Control/VBoxContainer/WeaponsAndItemsContainer/ItemsContainer/ItemsHBox/AvailableItemsScroll/AvailableItemsList
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
    for s in _stat_names():
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

    # Said last: it reads the equipped lists above, so the panel is fully built by
    # the time the title names what it is showing.
    _refresh_title()

## Names the target in the title. Separate from `_ready()` because the target can
## also be changed with the panel open - a title that only ever refreshes on entry
## is a title that lies about what is on screen.
func _refresh_title() -> void:
    var title := get_node_or_null("Control/VBoxContainer/Title") as Label
    if title != null:
        title.text = "Configure — %s Weapons & Items (Debug)" % _target_label()

func _get_player():
    var chars = get_tree().get_nodes_in_group("character")
    if chars.size() > 0:
        return chars[0]
    return null

## The entity the panel is editing: the one it was pointed at, or the player.
##
## Every read goes through here rather than through `_get_player()` directly, so
## "who am I configuring" is one decision in one place.
##
## A pointed-at entity that has gone away reads as **null, not as the player**.
## Falling back there would be the worst possible failure: an enemy killed while
## the panel is open would silently swap the panel over to the player's gear,
## under a title still naming an enemy, and every click after that edits the wrong
## entity. Null says "nothing to edit" instead.
##
## The check is `_was_pointed_at`, not `target_entity != null` - see that field.
func _get_target() -> Node:
    if _was_pointed_at:
        return target_entity if is_instance_valid(target_entity) else null
    return _get_player()

## Whether the current target is the player. Gates the `GlobalGameState` start-of-
## run fallbacks: those only make sense for the player, and applying them while
## configuring an enemy would silently change the *next* run instead.
func _target_is_player() -> bool:
    return _get_target() == _get_player()

## Names the target for the title, so a panel pointed at an enemy says so rather
## than reading as the player's own gear.
func _target_label() -> String:
    if _target_is_player():
        return "Player"
    var target := _get_target()
    return "Enemy" if target == null else str(target.name)

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
            var btn = UiMenuButton.new()
            btn.text = "Add " + display_name
            btn.pressed.connect(func(p=path): _on_add_weapon(p, container, cur_container))
            container.add_child(btn)
        file_name = dir.get_next()
    dir.list_dir_end()

func _populate_effect_items(container: VBoxContainer, result_container: VBoxContainer) -> void:
    for scene in ItemBuilder.load_scenes_from_dir(EFFECTS_PATH):
        var display_name := scene.resource_path.get_file().get_basename()
        var btn = UiMenuButton.new()
        btn.text = "Add " + display_name
        btn.pressed.connect(func(p=scene.resource_path, rc=result_container): _create_effect_item(p, rc))
        container.add_child(btn)

func _on_add_weapon(path: String, _avail_container: VBoxContainer, cur_container: VBoxContainer) -> void:
    var target = _get_target()
    if target and target.has_node("WeaponHolder"):
        var wh = target.get_node("WeaponHolder")
        wh.add_weapon(load(path))
        _refresh_equipped_list(cur_container)
    elif _target_is_player():
        # fallback: add to GlobalGameState for next run
        if Engine.has_singleton("GlobalGameState"):
            GlobalGameState.starting_weapons.append(path)
        else:
            push_warning("No player found and no GlobalGameState autoload")
    else:
        push_warning("ConfigurePanel: no WeaponHolder on the target")

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

    var effect_name = effect_scene_path.get_file().get_basename()
    var item := ItemBuilder.make_effect_item(
        "Effect: " + effect_name,
        "Grants effect: " + effect_name,
        effect_scene
    )
    _add_item_to_holder(item, result_container)

func _create_buff_item(stat_name: String, amount: float, result_container: VBoxContainer=null) -> void:
    var buff_scene: PackedScene = load(BUFF_PATH)
    if not buff_scene:
        push_warning("Could not load buff scene: " + BUFF_PATH)
        return

    var item := ItemBuilder.make_buff_item(
        "Buff_%s_%s" % [stat_name, str(amount)],
        "Buff: +%s %s" % [amount, stat_name],
        stat_name,
        {"flat": amount},
        buff_scene
    )
    _add_item_to_holder(item, result_container)

func _create_debuff_item(stat_name: String, amount: float, result_container: VBoxContainer=null) -> void:
    var debuff_scene: PackedScene = load(DEBUFF_PATH)
    if not debuff_scene:
        push_warning("Could not load debuff scene: " + DEBUFF_PATH)
        return

    var item := ItemBuilder.make_debuff_item(
        "Debuff_%s_%s" % [stat_name, str(amount)],
        "Debuff: -%s %s" % [amount, stat_name],
        stat_name,
        {"flat": -amount},
        debuff_scene
    )
    _add_item_to_holder(item, result_container)

func _create_stat_item(stat_name: String, amount: float, result_container: VBoxContainer=null) -> void:
    var item := ItemBuilder.make_stat_item(
        "Debug_%s_%s" % [stat_name, str(amount)],
        "%s %s (debug)" % [stat_name, amount],
        {stat_name: {"flat": amount}}
    )
    _add_item_to_holder(item, result_container)

func _add_item_to_holder(item: Item, result_container: VBoxContainer=null) -> void:
    var target = _get_target()
    if target and target.has_node("ItemHolder"):
        var ih = target.get_node("ItemHolder")
        ih.add_item(item)
        if result_container:
            _refresh_equipped_items(result_container)
    else:
        push_warning("No target present to receive item")

## The panel's own weapons list, for a caller with no container to hand.
## Every refresh falls back to this rather than requiring the argument, because
## the list is a fixed part of the scene - a null here is a caller with nothing to
## pass, not a panel that has no list.
func _weapons_list() -> VBoxContainer:
    return get_node_or_null(
        "Control/VBoxContainer/WeaponsAndItemsContainer/WeaponsContainer/WeaponsHBox/EquippedWeaponsScroll/EquippedWeaponsList"
    ) as VBoxContainer


func _items_list() -> VBoxContainer:
    return get_node_or_null(
        "Control/VBoxContainer/WeaponsAndItemsContainer/ItemsContainer/ItemsHBox/EquippedItemsScroll/EquippedItemsList"
    ) as VBoxContainer


func _refresh_equipped_list(container: VBoxContainer = null) -> void:
    if container == null:
        container = _weapons_list()
    if container == null:
        return
    # Clear old children
    for child in container.get_children():
        child.queue_free()
    var target = _get_target()
    if not target or not target.has_node("WeaponHolder"):
        var label := Label.new()
        label.text = "(No target in scene)"
        container.add_child(label)
        return
    var wh = target.get_node("WeaponHolder")
    for w in wh.weapons:
        var weapon_name := "Weapon"
        if w is Resource and w.get("name") != null:
            weapon_name = w.get("name")
        var h := HBoxContainer.new()
        var lbl := Label.new()
        lbl.text = weapon_name
        h.add_child(lbl)
        var rem := UiMenuButton.new()
        rem.text = "Remove"
        rem.pressed.connect(func(wref=w, curc=container): _on_remove_weapon(wref, curc))
        h.add_child(rem)
        container.add_child(h)

func _on_remove_weapon(weapon_inst, container: VBoxContainer) -> void:
    var target = _get_target()
    if target and target.has_node("WeaponHolder"):
        var wh = target.get_node("WeaponHolder")
        wh.remove_weapon(weapon_inst)
        _refresh_equipped_list(container)

func _refresh_equipped_items(container: VBoxContainer = null) -> void:
    if container == null:
        container = _items_list()
    if container == null:
        return
    # clear
    for c in container.get_children():
        c.queue_free()
    var target = _get_target()
    if not target or not target.has_node("ItemHolder"):
        var label := Label.new()
        label.text = "(No target in scene)"
        container.add_child(label)
        return
    var ih = target.get_node("ItemHolder")
    for it in ih.items:
        var item_name := "Item"
        if it is Resource and it.get("name") != null:
            item_name = it.get("name")
        var h := HBoxContainer.new()
        var lbl := Label.new()
        lbl.text = item_name
        h.add_child(lbl)
        var rem := UiMenuButton.new()
        rem.text = "Remove"
        rem.pressed.connect(func(iref=it, curc=container): _on_remove_item(iref, curc))
        h.add_child(rem)
        container.add_child(h)

func _on_remove_item(item_inst, container: VBoxContainer) -> void:
    var target = _get_target()
    if target and target.has_node("ItemHolder"):
        var ih = target.get_node("ItemHolder")
        ih.remove_item(item_inst)
        _refresh_equipped_items(container)

func _create_simple_item() -> void:
    # Create a tiny Item resource with one modifier and add it to the player's ItemHolder
    var item := ItemBuilder.make_stat_item("Debug Simple Item", "+5 damage (debug)", {"damage": {"flat": 5}})
    var items_cur: VBoxContainer = null
    if has_node("Control"):
        items_cur = $Control/VBoxContainer/WeaponsAndItemsContainer/ItemsContainer/ItemsHBox/EquippedItemsScroll/EquippedItemsList
    _add_item_to_holder(item, items_cur)

func _on_close_pressed():
    visible = false
    emit_signal("closed")

func _clear_all():
    var target = _get_target()
    if target:
        if target.has_node("WeaponHolder"):
            var wh = target.get_node("WeaponHolder")
            # iterate over a copy to avoid mutation while removing
            var weapons_copy = []
            for w in wh.weapons:
                weapons_copy.append(w)
            for wref in weapons_copy:
                wh.remove_weapon(wref)
        if target.has_node("ItemHolder"):
            var ih = target.get_node("ItemHolder")
            var items_copy = []
            for it in ih.items:
                items_copy.append(it)
            for iref in items_copy:
                ih.remove_item(iref)
    else:
        push_warning("ConfigurePanel: no target present to clear")

    # If there's a GlobalGameState autoload, clear starting lists so next run is
    # clean. Player only: these describe the *next* run, so clearing them while
    # configuring an enemy would change the player's loadout instead of the
    # enemy's.
    if _target_is_player() and Engine.has_singleton("GlobalGameState"):
        GlobalGameState.starting_weapons = []
        GlobalGameState.starting_items = []
