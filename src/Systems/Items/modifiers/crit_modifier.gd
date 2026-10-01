extends BaseModifier

@export var display_name: String = "Crit"
@export_multiline var tooltip_text: String = "Critical hits deal extra damage based on your critical chance and multiplier."
@export var trigger_event: String = "before_deal_damage"
@export var crit_multiplier_per_stack: float = 0.15

var _current_crit = 0
var _current_crit_multiplier = 0.0

func get_tooltip_stats() -> String:
    return "+%.2f crit multiplier per stack" % crit_multiplier_per_stack

func attachEventManager(em: Node):
    _cache_holder(em)
    em.subscribe(trigger_event, Callable(self, "_on_before_deal_damage"))
    em.subscribe("on_stat_changes", Callable(self, "_on_stat_changes"))

func _on_before_deal_damage(event):
    if randf() * 100 < _current_crit:
        var ctx: DamageContext = event["damage_context"]
        ctx.final_amount *= _current_crit_multiplier + (crit_multiplier_per_stack * (_active_stacks() - 1))
        ctx.is_crit = true
        event_manager.emit_event("on_crit", {"damage_context": ctx})

func _on_stat_changes(_event):
    _current_crit = stats.get_stat("critical_chance")
    _current_crit_multiplier = stats.get_stat("critical_multiplier")