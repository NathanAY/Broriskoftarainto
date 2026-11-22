class_name Wallet
extends RefCounted
## The only way money changes. The balance lives in the character's `money`
## base stat; going through here is what makes every change observable
## (`on_money_changed`) and tallied by source for the loop it happened in.
## See `docs/systems/economy.md`.


## The `economy` block of `game_config.json`.
static func config() -> Dictionary:
    return GameConfig.section("economy")


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
    if balance(character) < amount:
        return false
    _set_balance(character, balance(character) - amount, reason)
    return true


## Coins earned in `loop`, keyed by source.
static func income_for_loop(character: Character, loop: int) -> Dictionary:
    return character.income_by_loop.get(loop, {})


static func _set_balance(character: Character, value: float, source: String) -> void:
    var old := balance(character)
    character.stats.set_base_stat("money", value)
    character.event_manager.emit_event("on_money_changed", {"old": old, "new": value, "source": source})
