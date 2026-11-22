extends BaseModifier
## Free rerolls in every shop visit: one per stack, up to `max_free_rerolls`.
## Published as the `free_rerolls` stat, which the shop reads; a free reroll does
## not raise the reroll surcharge.

@export var display_name: String = "Regular Customer"
@export var trigger_event: String = ""


func get_tooltip_stats() -> String:
    return "One free reroll per shop per stack (max %d)" % int(_economy_config().get("max_free_rerolls", 1))


func attachEventManager(em: Node):
    _cache_holder(em)
    _refresh()


func _on_stacks_changed() -> void:
    _refresh()


func _refresh() -> void:
    _publish_stat_value("free_rerolls", float(mini(_active_stacks(), int(_economy_config().get("max_free_rerolls", 1)))))
