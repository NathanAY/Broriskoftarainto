extends RefCounted
class_name ItemTooltip

## Static builder of tooltip key-value lines for Item and BaseWeapon resources.

static func tooltip_lines(resource: Resource) -> PackedStringArray:
    var lines := PackedStringArray()
    if resource is BaseWeapon:
        lines.append("name: " + str(resource.name))
        lines.append("damage: " + str(resource.base_damage))
        lines.append("range: " + str(resource.weapon_range))
        lines.append("attack speed: " + str(resource.base_attack_speed))
        if resource.description:
            lines.append("description: " + str(resource.description))
    elif resource is Item:
        lines.append("name: " + str(resource.name))
        if resource.description:
            lines.append("description: " + str(resource.description))
    else:
        return lines

    for line in modifier_lines(resource.modifiers):
        lines.append(line)

    if resource is Item and resource.effect_scene.size() > 0:
        var effect_names := PackedStringArray()
        for scene in resource.effect_scene:
            effect_names.append(scene.resource_path.get_file().get_basename())
        lines.append("effects: " + ", ".join(effect_names))

    return lines

static func modifier_lines(modifiers: Dictionary) -> PackedStringArray:
    var lines := PackedStringArray()
    for stat_name in modifiers:
        var mod = modifiers[stat_name]
        if typeof(mod) != TYPE_DICTIONARY:
            continue
        for mod_type in mod:
            var value = mod[mod_type]
            if mod_type == "percent":
                lines.append("%s %s: %d%%" % [stat_name, mod_type, round(float(value) * 100.0)])
            else:
                lines.append("%s %s: %s" % [stat_name, mod_type, str(value)])
    return lines