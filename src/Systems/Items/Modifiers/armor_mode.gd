extends Node
class_name ArmorModifier

@export var display_name: String = "Armor"
@export_multiline var tooltip_text: String = "Armor reduces incoming damage."
@export var trigger_event: String = "before_take_damage"

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
    em.subscribe(trigger_event, Callable(self, "_on_before_take_damage"))
    em.subscribe("on_stat_changes", Callable(self, "_on_stat_changes"))

func _on_before_take_damage(event):
    var ctx: DamageContext = event["damage_context"]
    if not ctx or not stats:
        return

    var armor: float = stats.get_stat("armor")
    var multiplier: float = 1.0

    if armor >= 0:
        multiplier = 10.0 / (10.0 + armor)
    else:
        multiplier = 1.0 + (-armor / 10.0)  # handles negatives correctly

    ctx.final_amount *= multiplier
    ctx.armor_applied = int(armor)   # optional, for debugging/logging
    ctx.armor_damage_multiplier = multiplier

func _on_stat_changes(_data):
    # ensure we keep stats up to date
    if holder:
        stats = holder.get_node_or_null("Stats")
