extends PanelContainer
class_name TooltipUi

## Reusable hover tooltip card. Fill its text from a Resource via ItemTooltip.tooltip_lines()
## and wire it to any Control row with bind_to_row(). Follows the mouse while a row is hovered.

var _hovered_resource: Resource = null

@onready var label: Label = $Label


func show_for(resource: Resource) -> void:
    if resource == null:
        return
    _hovered_resource = resource
    label.text = "\n".join(ItemTooltip.tooltip_lines(resource))
    visible = true
    reset_size()
    _position()


func hide_tooltip() -> void:
    _hovered_resource = null
    visible = false


## Makes `row` hoverable: shows this tooltip for `resource` on mouse_entered, hides on mouse_exited.
## All descendant Controls are set to IGNORE so the whole row catches the hover.
func bind_to_row(row: Control, resource: Resource) -> void:
    row.mouse_filter = Control.MOUSE_FILTER_STOP
    for child in row.get_children():
        _set_mouse_ignore(child)
    row.mouse_entered.connect(func():
        show_for(resource)
    )
    row.mouse_exited.connect(hide_tooltip)


func _set_mouse_ignore(node: Node) -> void:
    if node is Control:
        node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for child in node.get_children():
        _set_mouse_ignore(child)


func _process(_delta: float) -> void:
    if not _hovered_resource or not is_instance_valid(self):
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
