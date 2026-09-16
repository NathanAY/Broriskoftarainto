extends PanelContainer
class_name ShopItemCard

## Prepared shop card scene: icon on top, ItemTooltip-style text below,
## and two side-by-side action buttons at the bottom.
## Display is set via set_item_display(); button wiring is done by ShopMenu
## so buy/lock and take/sell logic stays in one place.

@onready var icon_holder: CenterContainer = $Margin/VBox/IconHolder
@onready var info_scroll: ScrollContainer = $Margin/VBox/InfoScroll
@onready var info_label: Label = $Margin/VBox/InfoScroll/InfoLabel
@onready var primary_button: Button = $Margin/VBox/Buttons/PrimaryButton
@onready var secondary_button: Button = $Margin/VBox/Buttons/SecondaryButton

var item: Item = null


func set_item_display(p_item: Item) -> void:
    item = p_item
    _clear_icon()
    if item == null:
        info_label.text = ""
        return
    var icon: Control = ItemIconGenerator.generate_icon(item)
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _set_mouse_ignore(icon)
    icon_holder.add_child(icon)
    info_label.text = "\n\n".join(ItemTooltip.tooltip_lines(item))


func _clear_icon() -> void:
    if not is_node_ready():
        return
    for child in icon_holder.get_children():
        child.queue_free()


func _set_mouse_ignore(node: Node) -> void:
    if node is Control:
        (node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
    for child in node.get_children():
        _set_mouse_ignore(child)
