extends Node
class_name ItemPriceAnalyzer

## Returns the shop cost of an offer: its type price (stat, buff/debuff, effect,
## weapon), times its rarity's positive multiplier, times the loop growth
## `1 + item_price_growth_per_loop * (loop - 1)`, rounded. Every number is in the
## `economy` block of `game_config.json`.


## `loop` 0 means the loop of the running game. `discount` is the buyer's
## `shop_discount` (`Wallet.discount()`); a discounted price never drops below 1.
func get_price(resource: Resource, loop: int = 0, discount: float = 0.0) -> int:
    var price := float(_type_price(resource))
    if resource is Item:
        price *= Item.rarity_value("positive_multipliers", (resource as Item).rarity)
    price = roundi(price * _loop_growth(loop))
    if discount == 0.0:
        return int(price)
    return maxi(1, roundi(price * (1.0 - discount)))


## The price by type alone; `get_price` scales it by rarity and loop.
func _type_price(resource: Resource) -> int:
    var prices: Dictionary = Wallet.config().get("type_prices", {})
    var type := "stat"
    if resource is BaseWeapon:
        type = "weapon"
    elif resource is Item:
        var item := resource as Item
        if ItemTooltip.is_buff_item(item) or ItemTooltip.is_debuff_item(item):
            type = "buff"
        elif ItemTooltip.has_effect_scene(item):
            type = "effect"
    return int(prices.get(type, {"stat": 1, "buff": 2, "effect": 3, "weapon": 5}[type]))


func _loop_growth(loop: int) -> float:
    if loop <= 0:
        loop = StageManager.loop_of(self)
    var growth := float(Wallet.config().get("item_price_growth_per_loop", 0.0))
    return 1.0 + growth * (loop - 1)


## Sell value: a ratio of the current shop price (`sell_ratio` when `ratio` is
## negative), never below 1. It is a ratio of the *discounted* price, so a
## discount plus resale can never turn buy-then-sell into a profit.
func get_sell_price(resource: Resource, ratio: float = -1.0, loop: int = 0, discount: float = 0.0) -> int:
    if ratio < 0.0:
        ratio = float(Wallet.config().get("sell_ratio", 0.5))
    return mini(maxi(1, roundi(get_price(resource, loop, discount) * ratio)), get_price(resource, loop, discount))
