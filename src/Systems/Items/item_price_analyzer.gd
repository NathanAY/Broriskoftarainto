extends Node
class_name ItemPriceAnalyzer

## Returns the shop cost of an offer based on its type:
## stat item = 1, buff/debuff = 2, modifier = 3, weapon = 5.

const STAT_PRICE: int = 1
const BUFF_DEBUFF_PRICE: int = 2
const MODIFIER_PRICE: int = 3
const WEAPON_PRICE: int = 5

const DEFAULT_SELL_RATIO: float = 0.5

func get_price(resource: Resource) -> int:
    if resource is BaseWeapon:
        return WEAPON_PRICE
    if resource is Item:
        var item := resource as Item
        if ItemTooltip.is_buff_item(item) or ItemTooltip.is_debuff_item(item):
            return BUFF_DEBUFF_PRICE
        if ItemTooltip.has_effect_scene(item):
            return MODIFIER_PRICE
        return STAT_PRICE
    return STAT_PRICE

## Sell value of a collected pickup: a ratio of its shop price (default 50%).
func get_sell_price(resource: Resource, ratio: float = DEFAULT_SELL_RATIO) -> int:
    return maxi(1, roundi(get_price(resource) * ratio))