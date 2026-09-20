extends RefCounted
class_name ItemBuilder

static func make_stat_item(name: String, description: String, modifiers: Dictionary) -> Item:
    var item := Item.new()
    item.name = name
    item.description = description
    item.modifiers = modifiers
    return item

static func make_effect_item(name: String, description: String, effect_scene: PackedScene, extra_modifiers: Dictionary = {}) -> Item:
    var item := Item.new()
    item.name = name
    item.description = description
    item.effect_scene = [effect_scene]
    item.modifiers = extra_modifiers
    return item

static func make_buff_item(name: String, description: String, stat_name: String, modifier_value: Dictionary, buff_scene: PackedScene) -> Item:
    var item := Item.new()
    item.name = name
    item.description = description
    item.set_meta("type", "buff")

    var buff_instance: Buff = buff_scene.instantiate()
    buff_instance.modifiers = {stat_name: modifier_value}
    buff_instance.name = name
    item.effect_scene = [pack_instance(buff_instance)]
    buff_instance.free()
    return item

static func make_debuff_item(name: String, description: String, stat_name: String, modifier_value: Dictionary, debuff_scene: PackedScene) -> Item:
    var item := Item.new()
    item.name = name
    item.description = description
    item.set_meta("type", "debuff")

    var debuff_instance: DebuffSource = debuff_scene.instantiate()
    debuff_instance.modifiers = {stat_name: modifier_value}
    debuff_instance.name = name
    item.effect_scene = [pack_instance(debuff_instance)]
    debuff_instance.free()
    return item

static func pack_instance(instance: Node) -> PackedScene:
    var packed := PackedScene.new()
    packed.pack(instance)
    return packed

static func load_scenes_from_dir(path: String) -> Array[PackedScene]:
    var scenes: Array[PackedScene] = []
    var dir := DirAccess.open(path)
    if not dir:
        push_warning("Cannot open folder: " + path)
        return scenes

    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
        if file_name.ends_with(".tscn"):
            var scene_path := "%s/%s" % [path, file_name]
            var scene = load(scene_path)
            if scene is PackedScene:
                scenes.append(scene)
        file_name = dir.get_next()
    dir.list_dir_end()
    return scenes
