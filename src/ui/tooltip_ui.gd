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
    _clear_icon()
    separator.visible = false
    name_label.text = ""
    type_badge.visible = false
    icon_plate.visible = icon != null
    if icon != null:
        _add_icon(make_texture_icon(icon, HINT_ICON_SIZE))
    label.text = "[i][color=#%s]%s[/color][/i]" % [COLOR_MUTED.to_html(false), text]
    _show()


func hide_tooltip() -> void:
    _hovered_resource = null
    _hovered_text = ""
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


func _bind_hover(row: Control, show_callback: Callable) -> void:
    row.mouse_filter = Control.MOUSE_FILTER_STOP
    for child in row.get_children():
        set_mouse_ignore(child)
    row.mouse_entered.connect(show_callback)
    row.mouse_exited.connect(hide_tooltip)


func _process(_delta: float) -> void:
    if _hovered_resource == null and _hovered_text.is_empty():
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
