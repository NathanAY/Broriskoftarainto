# ChainModifier.gd
extends Node

var event_manager: EventManager = null
var holder: Node = null
var stats: Stats = null

func attachEventManager(em: Node):
    event_manager = em
    holder = em.get_parent()
    stats = holder.get_node("Stats")
    em.subscribe("before_deal_damage", Callable(self, "_on_before_deal_damage"))
    em.subscribe("on_stat_changes", Callable(self, "_on_stat_changes"))

func _on_before_deal_damage(event):
    var ctx: DamageContext = event["damage_context"]
    var stats: Stats = holder.get_node_or_null("Stats")
    if stats:
        var crit_chance = stats.get_stat("critical_chance")
        var crit_mult = stats.get_stat("critical_multiplier")
        if randf() < crit_chance:
            ctx.final_amount *= crit_mult
            ctx.is_crit = true

func _on_stat_changes(data):
    stats.get_stat("critical_chance")
    stats.get_stat("critical_multiplier")
    
