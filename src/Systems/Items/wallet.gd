class_name Wallet
extends RefCounted
## The only way money changes. The balance lives in the character's `money`
## base stat; going through here is what makes every change observable
## (`on_money_changed`) and tallied by source for the loop it happened in.
## See `docs/systems/economy.md`.


## The stats that only the wallet reads. Each is capped by `<stat>_cap` in the
## `economy` config.
const ECONOMY_STATS: Array[String] = [
    "stock_investment", "coin_gain", "interest_rate", "shop_discount", "resale_value",
]


## How each payday source reads in the run history.
const PAYDAY_LABELS := {"interest": "Interest", "dividend": "Stock Investment dividend"}


## The `economy` block of `game_config.json`.
static func config() -> Dictionary:
    return GameConfig.section("economy")


## An economy stat's value, held to its `<stat>_cap`. A curse can still drive it
## negative; each reader decides what negative means.
static func stat(character: Character, stat_name: String) -> float:
    var value := character.stats.get_stat(stat_name)
    var cap = config().get(stat_name + "_cap")
    return minf(value, float(cap)) if cap != null else value


## `base` coins scaled by `coin_gain`, never below 0.
static func coins_for(character: Character, base: float) -> float:
    return base * maxf(0.0, 1.0 + stat(character, "coin_gain"))


## Share of an item's price the shop takes off (negative is a surcharge).
static func discount(character: Character) -> float:
    return stat(character, "shop_discount")


## Share of an item's price paid when it is sold.
static func sell_ratio(character: Character) -> float:
    return clampf(float(config().get("sell_ratio", 0.5)) + stat(character, "resale_value"), 0.0, 1.0)


## Runs once per shop visit, in this order, because each step reads what the
## one before wrote:
## 1. interest on the money carried over from the last shop (this loop's income
##    excluded, so the rate rewards saving rather than multiplying kills),
## 2. the stock dividend, `floor(stock_investment)`,
## 3. stock growth, `stock × stock_growth`, added to the *base* so stock that
##    came from items keeps its growth after the item is sold.
## Returns the coins paid by source and emits `on_payday`.
static func payday(character: Character, loop: int) -> Dictionary:
    var economy := config()
    var breakdown := {}

    var income := 0.0
    for coins in income_for_loop(character, loop).values():
        income += float(coins)
    var carried := maxf(0.0, balance(character) - income)
    var interest := mini(floori(maxf(0.0, stat(character, "interest_rate")) * carried), int(economy.get("interest_cap", 10)))
    if interest > 0:
        breakdown["interest"] = float(interest)

    var stock := stat(character, "stock_investment")
    var dividend := floori(maxf(0.0, stock))
    if dividend > 0:
        breakdown["dividend"] = float(dividend)
    var cap := float(economy.get("stock_investment_cap", INF))
    var growth := clampf(stock * float(economy.get("stock_growth", 0.0)), 0.0, maxf(0.0, cap - stock))
    if growth > 0.0:
        character.stats.set_base_stat("stock_investment", float(character.stats.stats.get("stock_investment", 0.0)) + growth)
        RunHistory.record(character, "Stock growth", "stock_investment", growth)

    for source in breakdown:
        earn(character, breakdown[source], source)
        RunHistory.record(character, PAYDAY_LABELS.get(source, source), "coins", breakdown[source])
    character.event_manager.emit_event("on_payday", {"loop": loop, "breakdown": breakdown})
    return breakdown


static func balance(character: Character) -> float:
    return float(character.stats.stats.get("money", 0.0))


## Adds `amount` and records it under `source` ("kill", "boss", "sell", ...).
static func earn(character: Character, amount: float, source: String) -> void:
    var loop := StageManager.loop_of(character)
    var tally: Dictionary = character.income_by_loop.get_or_add(loop, {})
    tally[source] = float(tally.get(source, 0.0)) + amount
    _set_balance(character, balance(character) + amount, source)


## Takes `amount` if the character can afford it. Returns false, and changes
## nothing, when it cannot.
static func spend(character: Character, amount: float, reason: String) -> bool:
    if not can_afford(character, amount):
        return false
    _set_balance(character, balance(character) - amount, reason)
    return true


## How far into debt the character may spend: the `credit_limit` stat, which
## only exists while a `CreditLineModifier` is attached. 0 for everyone else.
static func credit(character: Character) -> float:
    return maxf(0.0, character.stats.get_stat("credit_limit"))


static func can_afford(character: Character, amount: float) -> bool:
    return balance(character) + credit(character) >= amount


## Takes `amount` whether or not it can be afforded, so it can push the balance
## below the credit limit. Only for charges the player did not choose (debt
## interest); a purchase goes through `spend`.
static func charge(character: Character, amount: float, reason: String) -> void:
    _set_balance(character, balance(character) - amount, reason)


## Coins earned in `loop`, keyed by source.
static func income_for_loop(character: Character, loop: int) -> Dictionary:
    return character.income_by_loop.get(loop, {})


static func _set_balance(character: Character, value: float, source: String) -> void:
    var old := balance(character)
    character.stats.set_base_stat("money", value)
    character.event_manager.emit_event("on_money_changed", {"old": old, "new": value, "source": source})
