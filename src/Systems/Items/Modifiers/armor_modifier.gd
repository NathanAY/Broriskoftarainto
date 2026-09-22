extends BaseModifier

@export var display_name: String = "Armor"
@export_multiline var tooltip_text: String = "Armor reduces incoming damage."
@export var trigger_event: String = "before_take_damage"
@export var armor_per_stack: float = 5.0

func get_tooltip_stats() -> String:
    return "+%d armor per stack" % int(armor_per_stack)

func attachEventManager(em: Node):
    _cache_holder(em)
    if not stats:
        return
    event_manager.subscribe(trigger_event, Callable(self, "_on_before_take_damage"))
    event_manager.subscribe("on_stat_changes", Callable(self, "_on_stat_changes"))

func _on_before_take_damage(event):
    var ctx: DamageContext = event["damage_context"]
    if not ctx or not stats:
        return

    var armor: float = stats.get_stat("armor") + armor_per_stack * (_active_stacks() - 1)
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