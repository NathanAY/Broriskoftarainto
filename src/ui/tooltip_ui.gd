extends ItemDisplayPanel
class_name TooltipUi

## Reusable hover tooltip. Renders a Resource in the shared `ItemDisplayPanel`
## look (icon + name + tone-colored stat rows) at a smaller scale than
## `ShopItemCard`, and follows the mouse while a bound row is hovered.
##
## Wire it to any Control with bind_to_row() / bind_to_row_text().

## Offset from the cursor, and the gap kept when flipping to stay on screen.
const MOUSE_OFFSET := Vector2(16, 16)
const SCREEN_MARGIN := 16

## Icon size that fills `TooltipUi.tscn`'s IconHolder without growing the plate.
const HINT_ICON_SIZE := Vector2(36, 36)

var _hovered_resource: Resource = null
var _hovered_text: String = ""
## The last buff shown through `show_buff()`, kept so `_process()` knows it has
## something to follow and so a hidden tooltip stops moving.
var _hovered_buff: BuffEntry = null

## Kept for callers/tests that read the tooltip body through `.label`.
@onready var label: RichTextLabel = info_label


func _ready() -> void:
    super()
    # A tooltip sizes itself to its text, so the body must not be a scroll area.
    hug_body_content()


func show_for(resource: Resource) -> void:
    if resource == null:
        return
    _hovered_resource = resource
    _hovered_text = ""
    _hovered_buff = null
    set_resource(resource)
    _show()


## Plain text hint (e.g. a stat description). No resource, no header rows:
## the text is shown as muted prose in the body. `icon` (e.g. the stat's own
## icon) fills the header plate; without one the plate is collapsed so no empty
## strip is left above the text.
func show_text(text: String, icon: Texture2D = null) -> void:
    if text.is_empty():
        return
    _hovered_resource = null
    _hovered_text = text
    _hovered_buff = null
    _clear_icon()
    separator.visible = false
    name_label.text = ""
    type_badge.visible = false
    icon_plate.visible = icon != null
    if icon != null:
        _add_icon(make_texture_icon(icon, HINT_ICON_SIZE))
    label.text = "[i][color=#%s]%s[/color][/i]" % [COLOR_MUTED.to_html(false), text]
    _show()


## Hover detail for a buff / debuff tile. A `BuffEntry` is a `RefCounted` rather
## than a `Resource`, so it cannot ride `show_for()`; the path is modelled on
## `show_text()` and reuses the same `_bind_hover()` wiring.
##
## Everything the tile does not have room for lives here: the stat rows at the
## summed total, the stack count against the cap, the countdown, the trigger and
## the stat's own explanation.
func show_buff(entry: BuffEntry) -> void:
    if entry == null:
        return
    _hovered_resource = null
    _hovered_text = ""
    _hovered_buff = entry

    name_label.text = entry.resolved_name()
    type_badge.visible = true
    type_badge.text = "Debuff" if entry.is_debuff else "Buff"
    separator.visible = true
    icon_plate.visible = true
    _add_icon(_buff_icon(entry))
    label.text = _build_buff_bbcode(entry)
    _show()


## The stat art the tile uses, at the tooltip's own icon size. Falls back to the
## shared default so the plate is never empty.
func _buff_icon(entry: BuffEntry) -> Control:
    var stat := BuffEntry.primary_stat(entry.modifiers)
    if stat.is_empty():
        return ItemDisplayPanel.make_texture_icon(Stats.get_stat_icon(""), HINT_ICON_SIZE)
    return ItemDisplayPanel.make_texture_icon(Stats.get_stat_icon(stat), HINT_ICON_SIZE)


## The body as BBCode, through the same `ItemCardRow` -> `_row_bbcode()` route
## the shop cards use so a buff's stat line is coloured exactly like an item's.
func _build_buff_bbcode(entry: BuffEntry) -> String:
    var rows: Array = []
    # `entry.modifiers` is already summed across the stack set, so this is the
    # total the stat actually moved by and not one stack's worth.
    rows.append_array(ItemTooltip.stat_rows(entry.modifiers))

    if entry.stack_count > 1:
        var text := "%d stacks" % entry.stack_count
        if entry.max_stacks > 0:
            text += " (max %d)" % entry.max_stacks
        rows.append(_buff_prose_row(text))

    if entry.duration > 0.0:
        rows.append(_buff_prose_row("%.1fs of %.1fs left" % [entry.remaining, entry.duration]))

    if not entry.trigger.is_empty():
        rows.append(_buff_prose_row("Triggers on %s" % ItemTooltip.humanize_trigger(entry.trigger)))

    # The effect's own sentence first, then the stat's explanation: both are
    # prose, so both go through the muted flavor styling rather than a stat row.
    if not entry.tooltip_text.is_empty():
        rows.append(_buff_prose_row(entry.tooltip_text))
    var stat_hint := ItemTooltip.stat_hint(BuffEntry.primary_stat(entry.modifiers))
    if not stat_hint.is_empty():
        rows.append(_buff_prose_row(stat_hint))

    return ItemDisplayPanel.build_bbcode(rows)


## A neutral EFFECT row: gold, one sentence, no tone to derive from a number.
func _buff_prose_row(text: String) -> ItemCardRow:
    var row := ItemCardRow.new()
    row.kind = ItemCardRow.Kind.EFFECT
    row.tone = ItemCardRow.Tone.NEUTRAL
    row.text = text
    return row


func hide_tooltip() -> void:
    _hovered_resource = null
    _hovered_text = ""
    _hovered_buff = null
    visible = false


func _show() -> void:
    visible = true
    reset_size()
    _position()


## Makes `row` hoverable: shows this tooltip for `resource` on mouse_entered, hides on mouse_exited.
## All descendant Controls are set to IGNORE so the whole row catches the hover.
func bind_to_row(row: Control, resource: Resource) -> void:
    _bind_hover(row, func(): show_for(resource))


## Like bind_to_row(), but shows a plain text hint (e.g. a stat description).
## `icon` is optional and fills the header plate when given.
func bind_to_row_text(row: Control, text: String, icon: Texture2D = null) -> void:
    _bind_hover(row, func(): show_text(text, icon))


## Like bind_to_row(), but for a buff tile. `entry` is captured by the closure, so
## the tooltip keeps showing the tile's own effect; `buff_ui.gd` rebinds when the
## tile's entry changes.
func bind_to_row_buff(row: Control, entry: BuffEntry) -> void:
    _bind_hover(row, func(): show_buff(entry))


func _bind_hover(row: Control, show_callback: Callable) -> void:
    row.mouse_filter = Control.MOUSE_FILTER_STOP
    for child in row.get_children():
        set_mouse_ignore(child)
    row.mouse_entered.connect(show_callback)
    row.mouse_exited.connect(hide_tooltip)


func _process(_delta: float) -> void:
    if _hovered_resource == null and _hovered_text.is_empty() and _hovered_buff == null:
        return
    if not is_instance_valid(self):
        return
    _position()


func _position() -> void:
    var viewport_size: Vector2 = get_viewport_rect().size
    var tooltip_size: Vector2 = size
    var mouse := get_global_mouse_position()
    var pos: Vector2 = mouse + MOUSE_OFFSET
    if pos.x + tooltip_size.x > viewport_size.x:
        pos.x = mouse.x - tooltip_size.x - SCREEN_MARGIN
    if pos.y + tooltip_size.y > viewport_size.y:
        pos.y = mouse.y - tooltip_size.y - SCREEN_MARGIN
    pos.x = maxf(pos.x, 0.0)
    pos.y = maxf(pos.y, 0.0)
    global_position = pos
