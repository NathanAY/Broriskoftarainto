extends BaseModifier
## A cost: after every payday, lose `tax_rate` of the money held (+
## `tax_rate_per_extra_stack` per extra stack), rounded down. Numbers come from
## the `economy_modifiers` config.

@export var display_name: String = "Tax Collector"
@export var trigger_event: String = "on_payday"


func _init() -> void:
    effect_kind = EffectKind.COST


func get_tooltip_stats() -> String:
    return "Lose %d%% of coins each shop" % roundi(_rate() * 100.0)


func attachEventManager(em: Node):
    _cache_holder(em)
    _subscribe("on_payday", _on_payday)


func _rate() -> float:
    var config := _economy_config()
    return clampf(float(config.get("tax_rate", 0.0)) + float(config.get("tax_rate_per_extra_stack", 0.0)) * (_active_stacks() - 1), 0.0, 1.0)


func _on_payday(_event: Dictionary) -> void:
    var character := holder as Character
    if character == null or Wallet.balance(character) <= 0.0:
        return  # nothing to tax, and a negative share of a debt would be a refund
    var tax := floorf(Wallet.balance(character) * _rate())
    if Wallet.spend(character, tax, "tax"):
        RunHistory.record(character, display_name, "coins", -tax)
