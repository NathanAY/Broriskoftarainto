extends RefCounted
class_name ModifierSummary

## What the character menu's Modifiers tab lists: every behavior modifier alive on
## a character, with identical ones merged into one entry.
##
## Read from the live nodes, not from the items, so it also covers what no item
## carries: a character's declared baseline (`CharacterData.modifiers`) and a
## weapon's built-in effects (knockback, poison...). Each entry is
## `{display, count, texture}`: `display` is the `ItemTooltip` effect display
## dictionary (name, text, stats, trigger, effect_kind), `count` the number of
## copies held, `texture` the effect's art.

const ICON_DIR := "res://src/Assets/modifiers/"


static func entries(character: Node) -> Array[Dictionary]:
    var merged: Dictionary = {}  # key -> entry, insertion-ordered
    if character == null:
        return []
    for holder_name in ["ItemHolder", "WeaponHolder"]:
        var holder := character.get_node_or_null(holder_name)
        if holder == null:
            continue
        for child in holder.get_children():
            if child is BaseModifier and not child.is_queued_for_deletion():
                _add(merged, child as BaseModifier)
    var result: Array[Dictionary] = []
    result.assign(merged.values())
    return result


## Replaces the children of `container` with one row per entry: art, the same
## effect line an item tooltip shows, and an `xN` badge when copies were merged.
static func populate(container: Container, character: Node) -> void:
    for child in container.get_children():
        # Freed at once: rows hold no callbacks, and a queued one would still be
        # counted as a row for the rest of the frame.
        container.remove_child(child)
        child.free()
    for entry in entries(character):
        container.add_child(_make_row(entry))


static func _make_row(entry: Dictionary) -> Control:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)

    var plate := PanelContainer.new()
    plate.add_theme_stylebox_override("panel", ItemDisplayPanel.make_panel_stylebox(ItemDisplayPanel.PANEL_BORDER))
    plate.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    plate.add_child(ItemDisplayPanel.make_texture_icon(entry["texture"], Vector2(40, 40)))
    row.add_child(plate)

    var effect := ItemTooltip.effect_row(entry["display"])
    var text := RichTextLabel.new()
    text.bbcode_enabled = true
    text.fit_content = true
    text.scroll_active = false
    text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    text.text = ItemDisplayPanel.build_bbcode([effect]) if effect != null else ""
    row.add_child(text)

    if int(entry["count"]) > 1:
        var badge := Label.new()
        badge.name = "Count"
        badge.text = "x%d" % int(entry["count"])
        badge.add_theme_color_override("font_color", ItemDisplayPanel.COLOR_HEADING)
        row.add_child(badge)
    return row


static func _add(merged: Dictionary, node: BaseModifier) -> void:
    var display := ItemTooltip.display_from_node(node, _node_name(node))
    var key := "|".join([display["name"], display["text"], display["stats"], display["trigger"]])
    # A held stack per item copy; a weapon built-in has none and counts as one.
    var count := maxi(1, node.stacks.size())
    if merged.has(key):
        merged[key]["count"] += count
    else:
        merged[key] = {"display": display, "count": count, "texture": icon_for(node)}


## Art named after the effect's scene (`KnockbackModifier.tscn` ->
## `knockbackmodifier.png`), the lookup `ItemIconGenerator` does. A node built from
## a repacked scene has no scene path, so its script name stands in.
static func icon_for(node: Node) -> Texture2D:
    var path := ICON_DIR + _node_name(node).to_lower().replace("_", "") + ".png"
    if not ResourceLoader.exists(path):
        path = ICON_DIR + "_default.png"
    return load(path)


static func _node_name(node: Node) -> String:
    if not node.scene_file_path.is_empty():
        return node.scene_file_path.get_file().get_basename()
    var script: Script = node.get_script()
    return script.resource_path.get_file().get_basename() if script else str(node.name)
