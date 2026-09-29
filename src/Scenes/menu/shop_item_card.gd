extends PanelContainer
class_name ShopItemCard

## Shop card scene: icon + name header, a structured/colored body built from
## `ItemTooltip.card_rows()`, a price plate, and two action buttons.
## Display is set via set_item_display(); button wiring is done by ShopMenu
## so buy/lock and take/sell logic stays in one place.

const HOVER_BORDER := Color(0.976471, 0.729412, 0.313726, 1)
const REST_BORDER := Color(0.278431, 0.301961, 0.352941, 1)
const WEAPON_BORDER := Color(0.905882, 0.494118, 0.156863, 1)
const LOCKED_BORDER := Color(0.360784, 0.690196, 0.909804, 1)
const HOVER_MODULATE := Color(1.06, 1.06, 1.06, 1)
const REST_MODULATE := Color(1, 1, 1, 1)
const UNAFFORDABLE_MODULATE := Color(0.55, 0.55, 0.6, 1)

const COLOR_POSITIVE := Color(0.478431, 0.870588, 0.478431, 1)
const COLOR_NEGATIVE := Color(0.952941, 0.443137, 0.443137, 1)
const COLOR_NEUTRAL := Color(0.784314, 0.803922, 0.847059, 1)
const COLOR_MUTED := Color(0.588235, 0.615686, 0.678431, 1)
const COLOR_HEADING := Color(1, 0.827451, 0.352941, 1)

const FADE_OUT_TIME := 0.15

@onready var icon_holder: CenterContainer = $Margin/VBox/Header/IconPlate/IconHolder
@onready var name_label: Label = $Margin/VBox/Header/NameBox/NameLabel
@onready var type_badge: Label = $Margin/VBox/Header/NameBox/TypeBadge
@onready var info_scroll: ScrollContainer = $Margin/VBox/InfoScroll
@onready var info_label: RichTextLabel = $Margin/VBox/InfoScroll/InfoLabel
@onready var price_plate: PanelContainer = $Margin/VBox/PricePlate
@onready var price_label: Label = $Margin/VBox/PricePlate/PriceLabel
@onready var primary_button: Button = $Margin/VBox/Buttons/PrimaryButton
@onready var secondary_button: Button = $Margin/VBox/Buttons/SecondaryButton

var item: Resource = null
var price: int = 0
var money: float = 0.0
var is_weapon: bool = false

var _locked: bool = false
var _affordable: bool = true
var _hovered: bool = false


func _ready() -> void:
    mouse_entered.connect(func() -> void:
        _hovered = true
        _refresh_border())
    mouse_exited.connect(func() -> void:
        _hovered = false
        _refresh_border())


func set_item_display(p_item: Resource) -> void:
    item = p_item
    is_weapon = p_item is BaseWeapon
    _clear_icon()
    type_badge.visible = is_weapon
    if item == null:
        name_label.text = ""
        info_label.text = ""
        return

    # Item resources carry raw ids like "Buff projectile_speed_multiplier".
    # Humanize so the header reads as a name, matching how the body stats and
    # the stats panel already render.
    name_label.text = ItemTooltip.humanize_effect_name(str(item.name))

    _make_icon(item)
    info_label.text = _build_bbcode(ItemTooltip.card_rows(item))


## Price shown in the plate above the buttons. Purely visual; the label text
## on the buttons is owned by ShopMenu.
func set_price(value: int) -> void:
    price = value
    var noun := "coin" if value == 1 else "coins"
    price_label.text = "%d %s" % [value, noun]
    _refresh_price_hint()


## The player's current money. Only used to explain an unaffordable price.
func set_money(value: float) -> void:
    money = value
    _refresh_price_hint()


func _refresh_price_hint() -> void:
    if price <= 0:
        price_label.tooltip_text = ""
    elif _affordable:
        price_label.tooltip_text = "Costs %d money." % price
    else:
        price_label.tooltip_text = "Costs %d money, you only have %d." % [price, int(money)]


func set_locked(locked: bool) -> void:
    _locked = locked
    _refresh_border()


func set_affordable(affordable: bool) -> void:
    _affordable = affordable
    primary_button.disabled = not affordable
    _refresh_price_hint()
    _refresh_border()


## Fades the card out and frees it. Used when an offer is bought, taken or
## sold so the row does not snap shut.
func fade_out_and_free() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var tween := create_tween()
    tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_TIME)
    tween.tween_callback(queue_free)


func _make_icon(source: Resource) -> void:
    var icon: Control
    if source is BaseWeapon:
        icon = _make_weapon_icon(source as BaseWeapon)
    else:
        icon = ItemIconGenerator.generate_icon(source as Item)
    _set_mouse_ignore(icon)
    icon_holder.add_child(icon)


func _make_weapon_icon(weapon: BaseWeapon) -> Control:
    var container := Control.new()
    container.custom_minimum_size = ItemIconGenerator.BASE_SIZE
    var rect := TextureRect.new()
    rect.texture = weapon.sprite if weapon.sprite else load("res://src/Assets/weapons/_default.png")
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    container.add_child(rect)
    return container


func _build_bbcode(rows: Array) -> String:
    var parts := PackedStringArray()
    for row in rows:
        var typed: ItemCardRow = row
        if typed.kind == ItemCardRow.Kind.NAME:
            # The name lives in the header, not the body.
            continue
        parts.append(_row_bbcode(typed))
    return "\n".join(parts)


func _row_bbcode(row: ItemCardRow) -> String:
    var color := _tone_color(row.tone)
    match row.kind:
        ItemCardRow.Kind.FLAVOR:
            return "[i][color=#%s]%s[/color][/i]" % [COLOR_MUTED.to_html(false), row.text]
        ItemCardRow.Kind.EFFECT:
            return "[color=#%s]%s[/color]" % [COLOR_HEADING.to_html(false), row.text]
        _:
            return "[color=#%s]%s[/color]" % [color.to_html(false), row.to_display()]


func _tone_color(tone: int) -> Color:
    match tone:
        ItemCardRow.Tone.POSITIVE:
            return COLOR_POSITIVE
        ItemCardRow.Tone.NEGATIVE:
            return COLOR_NEGATIVE
        _:
            return COLOR_NEUTRAL


func _refresh_border() -> void:
    var color := REST_BORDER
    if _locked:
        color = LOCKED_BORDER
    elif _hovered:
        color = HOVER_BORDER
    elif is_weapon:
        color = WEAPON_BORDER
    add_theme_stylebox_override("panel", _make_border_box(color))

    if not _affordable:
        modulate = UNAFFORDABLE_MODULATE
    elif _hovered:
        modulate = HOVER_MODULATE
    else:
        modulate = REST_MODULATE


func _make_border_box(border_color: Color) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = Color(0.14902, 0.160784, 0.196078, 1)
    box.set_border_width_all(2)
    box.border_color = border_color
    box.set_corner_radius_all(8)
    box.shadow_color = Color(0, 0, 0, 0.298039)
    box.shadow_size = 6
    return box


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
