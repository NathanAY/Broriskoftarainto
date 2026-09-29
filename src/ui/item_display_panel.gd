extends PanelContainer
class_name ItemDisplayPanel

## Base panel for any UI that displays an item / weapon / character resource:
## an icon + name header, a tone-colored body of stat rows, and nothing else.
##
## `ShopItemCard` and `TooltipUi` both extend this. It owns the parts that
## would otherwise be copy-pasted:
##   - the palette (positive / negative / neutral / muted / heading)
##   - turning `ItemTooltip.card_rows()` into BBCode
##   - building the icon for an Item or a BaseWeapon
##   - `set_mouse_ignore()` recursion
##
## Subclasses add their own chrome (price plate, buttons, hover following) and
## override `_on_resource_changed()` when they need to react to a new resource.

# --- shared palette ---------------------------------------------------------

const COLOR_POSITIVE := Color(0.478431, 0.870588, 0.478431, 1)
const COLOR_NEGATIVE := Color(0.952941, 0.443137, 0.443137, 1)
const COLOR_NEUTRAL := Color(0.784314, 0.803922, 0.847059, 1)
const COLOR_MUTED := Color(0.588235, 0.615686, 0.678431, 1)
const COLOR_HEADING := Color(1, 0.827451, 0.352941, 1)

const PANEL_BG := Color(0.14902, 0.160784, 0.196078, 1)
const PANEL_BORDER := Color(0.278431, 0.301961, 0.352941, 1)
const PANEL_SHADOW := Color(0, 0, 0, 0.298039)
const PANEL_RADIUS := 8

@onready var icon_holder: CenterContainer = $Margin/VBox/Header/IconPlate/IconHolder
@onready var icon_plate: PanelContainer = $Margin/VBox/Header/IconPlate
@onready var name_label: Label = $Margin/VBox/Header/NameBox/NameLabel
@onready var type_badge: Label = $Margin/VBox/Header/NameBox/TypeBadge
@onready var info_scroll: ScrollContainer = $Margin/VBox/InfoScroll
@onready var info_label: RichTextLabel = $Margin/VBox/InfoScroll/InfoLabel
@onready var separator: HSeparator = $Margin/VBox/Separator

var item: Resource = null
var is_weapon: bool = false


func _ready() -> void:
    _apply_panel_style(PANEL_BORDER)


## Turns the body into a content-hugging block instead of a scroll area.
## A ScrollContainer reports a zero minimum size on a scrolling axis, which
## collapses the body when the panel sizes itself to its content. Disabling
## scrolling makes it report the label's real height instead. Used by the
## tooltip; the card keeps its scrollable body because it has a fixed height.
func hug_body_content() -> void:
    info_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED


## Fills the header and body from a resource. Safe to call with `null` to clear.
func set_resource(resource: Resource) -> void:
    item = resource
    is_weapon = resource is BaseWeapon
    _clear_icon()
    type_badge.visible = is_weapon
    if resource == null:
        name_label.text = ""
        info_label.text = ""
        _on_resource_changed()
        return

    name_label.text = display_name(resource)
    icon_plate.visible = true
    separator.visible = true
    _add_icon(make_icon(resource))
    info_label.text = build_bbcode(ItemTooltip.card_rows(resource), resource)
    _on_resource_changed()


## Override in subclasses to react to a new resource (borders, badges...).
## Called at the end of set_resource(), including for `null`.
func _on_resource_changed() -> void:
    pass


# --- static helpers ---------------------------------------------------------

## Human-readable name for a resource. Item resources carry raw ids like
## "Buff projectile_speed_multiplier", so they are humanized.
static func display_name(resource: Resource) -> String:
    if resource == null:
        return ""
    # CharacterData spells it `display_name`; without this branch the generic
    # check below fails and the header renders the .tres path.
    if resource is CharacterData:
        return str((resource as CharacterData).display_name)
    if "name" in resource:
        return ItemTooltip.humanize_effect_name(str(resource.name))
    return str(resource)


## Placeholder used when a character resource has no art assigned at all, so
## the icon plate is never empty.
const CHARACTER_PLACEHOLDER := "res://src/Assets/character/potato.png"


## The portrait to show for a character: its own small icon, else its sprite,
## else the shared placeholder.
static func character_icon_texture(character: CharacterData) -> Texture2D:
    if character != null:
        if character.small_icon:
            return character.small_icon
        if character.sprite:
            return character.sprite
    if ResourceLoader.exists(CHARACTER_PLACEHOLDER):
        return load(CHARACTER_PLACEHOLDER)
    return null


## Builds the icon Control for an Item, a BaseWeapon or a CharacterData.
## Falls back to the default weapon sprite / default modifier icon.
static func make_icon(resource: Resource) -> Control:
    if resource is CharacterData:
        return _make_texture_icon(character_icon_texture(resource as CharacterData))
    if resource is BaseWeapon:
        return _make_weapon_icon(resource as BaseWeapon)
    if resource is Item:
        return ItemIconGenerator.generate_icon(resource as Item)
    var container := Control.new()
    container.custom_minimum_size = ItemIconGenerator.BASE_SIZE
    return container


## A square icon holder holding one texture, centred and aspect-preserved.
static func _make_texture_icon(texture: Texture2D) -> Control:
    var container := Control.new()
    container.custom_minimum_size = ItemIconGenerator.BASE_SIZE
    var rect := TextureRect.new()
    rect.texture = texture
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    container.add_child(rect)
    return container


static func _make_weapon_icon(weapon: BaseWeapon) -> Control:
    var texture: Texture2D = weapon.sprite if weapon.sprite else load("res://src/Assets/weapons/_default.png")
    return _make_texture_icon(texture)


## Renders card rows as BBCode. The name row is skipped because it is already
## in the header. Resources with no structured rows (e.g. CharacterData) fall
## back to the flat tooltip lines so nothing renders blank.
static func build_bbcode(rows: Array, resource: Resource = null) -> String:
    var parts := PackedStringArray()
    for row in rows:
        var typed: ItemCardRow = row
        if typed.kind == ItemCardRow.Kind.NAME:
            continue
        parts.append(_row_bbcode(typed))
    if parts.is_empty() and resource != null:
        return "\n".join(ItemTooltip.tooltip_lines(resource))
    return "\n".join(parts)


static func _row_bbcode(row: ItemCardRow) -> String:
    match row.kind:
        ItemCardRow.Kind.FLAVOR:
            return "[i][color=#%s]%s[/color][/i]" % [COLOR_MUTED.to_html(false), row.text]
        ItemCardRow.Kind.EFFECT:
            return "[color=#%s]%s[/color]" % [COLOR_HEADING.to_html(false), row.text]
        _:
            return "[color=#%s]%s[/color]" % [tone_color(row.tone).to_html(false), row.to_display()]


static func tone_color(tone: int) -> Color:
    match tone:
        ItemCardRow.Tone.POSITIVE:
            return COLOR_POSITIVE
        ItemCardRow.Tone.NEGATIVE:
            return COLOR_NEGATIVE
        _:
            return COLOR_NEUTRAL


## Makes a node tree click-through so the row that owns the tooltip keeps
## receiving the hover.
static func set_mouse_ignore(node: Node) -> void:
    if node is Control:
        (node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
    for child in node.get_children():
        set_mouse_ignore(child)


# --- panel styling ----------------------------------------------------------

## The shared card look: dark fill, 2px border, rounded corners and a drop
## shadow. Exposed as a static so panels that are not ItemDisplayPanel
## subclasses (the compact character grid card) stay in the same visual kit.
static func make_panel_stylebox(border_color: Color) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = PANEL_BG
    box.set_border_width_all(2)
    box.border_color = border_color
    box.set_corner_radius_all(PANEL_RADIUS)
    box.shadow_color = PANEL_SHADOW
    box.shadow_size = 6
    return box


func _apply_panel_style(border_color: Color) -> void:
    add_theme_stylebox_override("panel", make_panel_stylebox(border_color))


# --- icon plumbing ----------------------------------------------------------

func _add_icon(icon: Control) -> void:
    if icon == null:
        return
    set_mouse_ignore(icon)
    icon_holder.add_child(icon)


func _clear_icon() -> void:
    if not is_node_ready():
        return
    # Freed immediately, not queued: `queue_free()` leaves the old icon in the
    # tree for the rest of the frame, so switching resources twice in a row
    # would stack icons in the plate. Nothing connects to an icon, so there is
    # no callback mid-free to worry about.
    for child in icon_holder.get_children():
        child.free()
