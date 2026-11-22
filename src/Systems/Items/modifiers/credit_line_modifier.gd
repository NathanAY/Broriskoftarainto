extends BaseModifier
## The Tycoon's signature: the holder may spend into debt, down to
## `-credit_limit` (a provided stat, so items can raise it). While the balance
## is negative the `in_debt` condition is on and damage is cut by
## `debt_damage_penalty`. Every time the shop opens, before payday, the debt
## grows by `debt_interest` of itself (rounded up). Numbers come from the
## `economy_modifiers` config. Character-only: its generation weight is 0.

@export var display_name: String = "Credit Line"
@export var trigger_event: String = "on_shop_enter"

var _penalty: Dictionary = {}


func get_tooltip_stats() -> String:
    var config := _economy_config()
    return "Spend up to %d coins into debt. Debt grows %d%% every shop and cuts damage by %d%%" % [
        int(config.get("credit_limit", 0)), roundi(float(config.get("debt_interest", 0.0)) * 100.0),
        roundi(float(config.get("debt_damage_penalty", 0.0)) * 100.0)]


func attachEventManager(em: Node):
    provided_stat = "credit_limit"
    provided_stat_default = float(_economy_config().get("credit_limit", 0))
    _cache_holder(em)
    if stats:
        _penalty = {"damage": {"percent": -float(_economy_config().get("debt_damage_penalty", 0.0))}, "condition": {"in_debt": 1}}
        stats.add_modifier(_penalty)
    _subscribe("on_stat_changes", _on_stat_changes)
    _subscribe("on_shop_enter", _on_shop_enter)


func detach() -> void:
    if is_instance_valid(stats) and not _penalty.is_empty():
        stats.remove_modifier(_penalty)
        stats.set_condition("in_debt", 0.0)
    super.detach()


func _on_stat_changes(event: Dictionary) -> void:
    if event.get("stat_name") == "money" and stats:
        stats.set_condition("in_debt", 1.0 if float(event.get("final_value", 0.0)) < 0.0 else 0.0)


func _on_shop_enter(_event: Dictionary) -> void:
    var character := holder as Character
    if character == null or Wallet.balance(character) >= 0.0:
        return
    Wallet.charge(character, ceilf(-Wallet.balance(character) * float(_economy_config().get("debt_interest", 0.0))), "debt_interest")
