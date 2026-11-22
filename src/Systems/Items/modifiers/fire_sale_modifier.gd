extends BaseModifier
## Selling anything also adds `price × stock_per_coin` to `stock_investment`,
## × `1 + bonus_per_extra_stack × (stacks - 1)`. Numbers come from the
## `economy_modifiers` config.

@export var display_name: String = "Fire Sale"
@export var trigger_event: String = "on_sell"


func get_tooltip_stats() -> String:
    return "Each coin from selling adds %s Stock Investment" % ItemTooltip.format_value(_stock_per_coin()).trim_prefix("+")


func attachEventManager(em: Node):
    _cache_holder(em)
    _subscribe("on_sell", _on_sell)


func _stock_per_coin() -> float:
    var config := _economy_config()
    return float(config.get("stock_per_coin", 0.0)) * (1.0 + float(config.get("bonus_per_extra_stack", 0.0)) * (_active_stacks() - 1))


func _on_sell(event: Dictionary) -> void:
    if not stats:
        return
    var gained := float(event.get("price", 0)) * _stock_per_coin()
    stats.set_base_stat("stock_investment", float(stats.stats.get("stock_investment", 0.0)) + gained)
