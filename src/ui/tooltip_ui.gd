extends PanelContainer
class_name TooltipUi

## Reusable hover tooltip card. Fill its text from a Resource via ItemTooltip.tooltip_lines()
## or directly via show_text(); wire it to any Control row with bind_to_row() /
## bind_to_row_text(). Follows the mouse while a row is hovered.

var _hovered_resource: Resource = null
var _hovered_text: String = ""

@onready var label: Label = $Label


func show_for(resource: Resource) -> void:
    if resource == null:
        return
    _hovered_resource = resource
    _hovered_text = ""
    label.text = "\n".join(ItemTooltip.tooltip_lines(resource))
    _show()


func show_text(text: String) -> void:
    if text.is_empty():
        return
    _hovered_resource = null
    _hovered_text = text
    label.text = text
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
func bind_to_row_text(row: Control, text: String) -> void:
    _bind_hover(row, func(): show_text(text))


func _bind_hover(row: Control, show_callback: Callable) -> void:
    row.mouse_filter = Control.MOUSE_FILTER_STOP
    for child in row.get_children():
        _set_mouse_ignore(child)
    row.mouse_entered.connect(show_callback)
    row.mouse_exited.connect(hide_tooltip)


func _set_mouse_ignore(node: Node) -> void:
    if node is Control:
        node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for child in node.get_children():
        _set_mouse_ignore(child)


func _process(_delta: float) -> void:
    if _hovered_resource == null and _hovered_text.is_empty():
        return
    if not is_instance_valid(self):
        return
    _position()


func _position() -> void:
    var viewport_size: Vector2 = get_viewport_rect().size
    var tooltip_size: Vector2 = size
    var pos: Vector2 = get_global_mouse_position() + Vector2(16, 16)
    if pos.x + tooltip_size.x > viewport_size.x:
        pos.x = get_global_mouse_position().x - tooltip_size.x - 16
    if pos.y + tooltip_size.y > viewport_size.y:
        pos.y = get_global_mouse_position().y - tooltip_size.y - 16
    pos.x = maxf(pos.x, 0.0)
    pos.y = maxf(pos.y, 0.0)
    global_position = pos
