extends Node

# Responsible for applying selected CharacterData to the local Stats node.
func _ready():
    # Wait until owner (Character) is ready and has a Stats child
    var stats_node = null
    if owner and owner.has_node("Stats"):
        stats_node = owner.get_node("Stats")
    if not stats_node:
        return

    var char_path = null
    if typeof(GlobalGameState) != TYPE_NIL and GlobalGameState.starting_character != null:
        char_path = GlobalGameState.starting_character
    if not char_path:
        return

    var char_res: Resource = null
    if typeof(char_path) == TYPE_STRING:
        char_res = load(char_path)
    elif typeof(char_path) == TYPE_OBJECT:
        char_res = char_path

    if not char_res:
        return

    var sprite: Sprite2D = owner.get_node("Node2D/Sprite2D")
    for child in sprite.get_children():
        child.queue_free()
        
    load_custom_sprites(char_res, sprite)

    # Apply base stats (overwrite base values)
    for stat_name in char_res.base_stats.keys():
        var v = char_res.base_stats[stat_name]
        if stats_node.has_method("set_base_stat"):
            stats_node.set_base_stat(stat_name, float(v))

    # Apply character modifiers (see _apply_modifier for the two entry kinds)
    for mod in char_res.modifiers:
        _apply_modifier(owner, stats_node, mod)

    # Apply starting items
    if owner.has_node("ItemHolder"):
        var item_holder :ItemHolder = owner.get_node("ItemHolder")
        for item in char_res.starting_items:
            item_holder.add_item(item)

    # Apply starting weapons once the Character (owner) is fully ready: WeaponHolder
    # resolves its @onready hold_owner in its own _ready, which runs before the
    # owner's ready. Equipping before the owner is ready fails because children
    # (timer, sprite) cannot be added to a character still entering the tree, so
    # same-timing deferred calls race with later weapon changes. Waiting on the
    # owner's ready signal keeps weapon setup deterministic during scene load.
    if owner.has_node("WeaponHolder"):
        var weapon_holder := owner.get_node("WeaponHolder")
        if owner.is_node_ready():
            _add_starting_weapons(weapon_holder, char_res.starting_weapons)
        else:
            owner.ready.connect(_add_starting_weapons.bind(weapon_holder, char_res.starting_weapons))


func _add_starting_weapons(weapon_holder: Node, starting_weapons: Array[BaseWeapon]) -> void:
    for weapon in starting_weapons:
        weapon_holder.add_weapon(weapon)


## Apply one entry of `CharacterData.modifiers` to the spawned character.
func _apply_modifier(character: Node, stats_node: Node, mod: Variant) -> void:
    # One entry in CharacterData.modifiers is one of two things, dispatched by
    # type so no stat is ever named here:
    #   Dictionary  -> a value: passed to Stats.add_modifier
    #                  (e.g. {"armor": {"flat": 4}})
    #   PackedScene -> a behavior: a modifier scene instantiated and wired to
    #                  this character (e.g. ArmorModifier.tscn, which is what
    #                  makes the `armor` value actually reduce damage)
    # A character that needs a brand new behavior only lists that modifier's
    # scene; nothing in this file changes.
    if mod is Dictionary:
        if stats_node.has_method("add_modifier"):
            stats_node.add_modifier(mod)
    elif mod is PackedScene:
        var em := character.get_node_or_null("EventManager") as EventManager
        BaseModifier.attach(mod, _modifier_host(character), em)
    else:
        push_warning("CharacterInitializer: unsupported modifier entry %s (%s)"
            % [str(mod), type_string(typeof(mod))])


## Where a character's behavior modifiers live. ItemHolder keeps them next to
## the effect nodes items add; the character itself is the fallback for scenes
## without an ItemHolder. Only grouping matters: a modifier resolves its holder
## from the EventManager's parent, not from its own position in the tree.
func _modifier_host(character: Node) -> Node:
    var holder: Node = character.get_node_or_null("ItemHolder")
    return holder if holder != null else character


func load_custom_sprites(char_res: Resource, owner_sprite: Sprite2D):
    # 1. Get the directory path from the resource path
    var dir_path = char_res.resource_path.get_base_dir()
    
    # 2. Open the directory
    var dir = DirAccess.open(dir_path)
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        
        while file_name != "":
            # 3. Check if it's a file, ends in .png, and doesn't contain "icon"
            if not dir.current_is_dir() and file_name.ends_with(".png") and not "icon" in file_name:
                var full_path = dir_path.path_join(file_name)
                
                # 4. Create the Sprite2D
                var sprite: Sprite2D = Sprite2D.new()
                sprite.texture = load(full_path)
                owner_sprite.add_child(sprite)
                print("Loaded sprite: ", full_path)
            
            file_name = dir.get_next()
        dir.list_dir_end()
