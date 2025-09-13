extends Node
class_name ArmorModifier

var event_manager: EventManager = null
var holder: Node = null
var stats: Stats = null

func attachEventManager(em: Node):
    event_manager = em
    holder = em.get_parent()
    stats = holder.get_node_or_null("Stats")
    if not stats:
        push_warning("ArmorModifier: Stats not found on holder %s" % holder.name)
        return
    em.subscribe("before_take_damage", Callable(self, "_on_before_take_damage"))
    em.subscribe("on_stat_changes", Callable(self, "_on_stat_changes"))

func _on_before_take_damage(event):
    var ctx: DamageContext = event["damage_context"]
    if not ctx or not stats:
        return

    var armor: float = stats.get_stat("armor")
    var multiplier: float = 1.0

    if armor >= 0:
        multiplier = 100.0 / (100.0 + armor)
    else:
        multiplier = 1.0 + (-armor / 100.0)  # handles negatives correctly

    ctx.final_amount *= multiplier
    ctx.armor_applied = armor   # optional, for debugging/logging
    ctx.armour_damage_multiplier = multiplier

func _on_stat_changes(_data):
    # ensure we keep stats up to date
    if holder:
        stats = holder.get_node_or_null("Stats")
