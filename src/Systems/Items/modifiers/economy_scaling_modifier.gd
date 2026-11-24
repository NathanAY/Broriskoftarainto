extends BaseModifier
class_name EconomyScalingModifier
## Turns an economy value into a combat stat: `target_stat` gains
## `per_unit × source_stat`, capped at `cap + cap_per_extra_stack × (stacks - 1)`.
## One script, two scenes:
## - `GildedEdgeModifier`: coins held (`money`) -> `damage`
## - `MarketRallyModifier`: `stock_investment` -> `attack_speed`
## Numbers come from the scene's block in the `economy_modifiers` config.

@export var display_name: String = "Gilded Edge"
@export var trigger_event: String = ""
## The stat the bonus is read from (`money` is the wallet balance).
@export var source_stat: String = "money"
## The stat the bonus is published into.
@export var target_stat: String = "damage"
## How the source reads in the tooltip ("coin held", "stock").
@export var source_label: String = "coin held"


func get_tooltip_stats() -> String:
    return "+%s %s per %s (max +%s, +%s per stack)" % [
        ItemTooltip.format_value(_per_unit()).trim_prefix("+"), target_stat.capitalize(), source_label,
        ItemTooltip.format_value(_cap()).trim_prefix("+"),
        ItemTooltip.format_value(float(_economy_config().get("cap_per_extra_stack", 0.0))).trim_prefix("+")]


func attachEventManager(em: Node):
    _cache_holder(em)
    _subscribe("on_stat_changes", _on_stat_changes)
    _refresh()


func _on_stacks_changed() -> void:
    _refresh()


func _on_stat_changes(event: Dictionary) -> void:
    if event.get("stat_name") == source_stat:
        _refresh()


func _per_unit() -> float:
    return float(_economy_config().get("per_unit", 0.0))


func _cap() -> float:
    var config := _economy_config()
    return float(config.get("cap", 0.0)) + float(config.get("cap_per_extra_stack", 0.0)) * (_active_stacks() - 1)


func _refresh() -> void:
    if not stats:
        return
    _publish_stat_value(target_stat, minf(maxf(0.0, stats.get_stat(source_stat)) * _per_unit(), _cap()))
