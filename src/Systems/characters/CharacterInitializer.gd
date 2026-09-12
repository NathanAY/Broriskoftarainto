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

    # Apply modifiers (additive modifier dictionaries)
    for mod in char_res.modifiers:
        if stats_node.has_method("add_modifier"):
            stats_node.add_modifier(mod)

    # Apply starting items
    if owner.has_node("ItemHolder"):
        var item_holder :ItemHolder = owner.get_node("ItemHolder")
        for item in char_res.starting_items:
            item_holder.add_item(item)

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
