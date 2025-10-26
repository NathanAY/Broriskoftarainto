# ChainModifier.gd
extends Node

var event_manager: EventManager = null
var holder: Node = null
var stats: Stats = null

var _current_crit = 0
var _current_crit_multiplier = 0.0

func attachEventManager(em: Node):
    event_manager = em
    holder = em.get_parent()
    stats = holder.get_node("Stats")
    em.subscribe("before_deal_damage", Callable(self, "_on_before_deal_damage"))
    em.subscribe("on_stat_changes", Callable(self, "_on_stat_changes"))

func _on_before_deal_damage(event):
    if randf() * 100 < _current_crit:
        var ctx: DamageContext = event["damage_context"]
        ctx.final_amount *= _current_crit_multiplier
        ctx.is_crit = true
        event_manager.emit_event("on_crit", [{"damage_context": ctx}])

func _on_stat_changes(_event):
    _current_crit = stats.get_stat("critical_chance")
    _current_crit_multiplier = stats.get_stat("critical_multiplier")
    
