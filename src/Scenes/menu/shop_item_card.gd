extends ItemDisplayPanel
class_name ShopItemCard

## Shop card: the shared `ItemDisplayPanel` header/body, plus a price plate and
## two action buttons. Display is set via set_item_display(); button wiring is
## done by ShopMenu so buy/lock and take/sell logic stays in one place.

const HOVER_BORDER := Color(0.976471, 0.729412, 0.313726, 1)
const WEAPON_BORDER := Color(0.905882, 0.494118, 0.156863, 1)
const LOCKED_BORDER := Color(0.360784, 0.690196, 0.909804, 1)
const HOVER_MODULATE := Color(1.06, 1.06, 1.06, 1)
const REST_MODULATE := Color(1, 1, 1, 1)
const UNAFFORDABLE_MODULATE := Color(0.55, 0.55, 0.6, 1)

const FADE_OUT_TIME := 0.15

@onready var price_plate: PanelContainer = $Margin/VBox/PricePlate
@onready var price_label: Label = $Margin/VBox/PricePlate/PriceLabel
@onready var primary_button: Button = $Margin/VBox/Buttons/PrimaryButton
@onready var secondary_button: Button = $Margin/VBox/Buttons/SecondaryButton

var price: int = 0
var money: float = 0.0

var _locked: bool = false
var _affordable: bool = true
var _hovered: bool = false
var _resolving: bool = false


func _ready() -> void:
    super()
    mouse_entered.connect(func() -> void:
        _hovered = true
        _refresh_border())
    mouse_exited.connect(func() -> void:
        _hovered = false
        _refresh_border())


## Card-specific alias so existing callers keep their vocabulary.
func set_item_display(p_item: Resource) -> void:
    set_resource(p_item)


func _on_resource_changed() -> void:
    _refresh_border()


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
    _resolving = true
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var tween := create_tween()
    tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_TIME)
    tween.tween_callback(queue_free)


## True once this card has been taken/sold/bought. The node is still alive
## during the fade-out tween, so callers that count "live" offers must not
## count a card that is already being resolved.
func is_resolving() -> bool:
    return _resolving


func _refresh_price_hint() -> void:
    if price <= 0:
        price_label.tooltip_text = ""
    elif _affordable:
        price_label.tooltip_text = "Costs %d money." % price
    else:
        price_label.tooltip_text = "Costs %d money, you only have %d." % [price, int(money)]


func _refresh_border() -> void:
    var color := PANEL_BORDER
    if _locked:
        color = LOCKED_BORDER
    elif _hovered:
        color = HOVER_BORDER
    elif is_weapon:
        color = WEAPON_BORDER
    _apply_panel_style(color)

    if not _affordable:
        modulate = UNAFFORDABLE_MODULATE
    elif _hovered:
        modulate = HOVER_MODULATE
    else:
        modulate = REST_MODULATE
