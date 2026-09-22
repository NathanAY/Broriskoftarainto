extends BaseModifier

@export var display_name: String = "Life Leach"
@export var trigger_event: String = "on_hit"
@export var bonus_per_stack: float = 0.2 # +20% leech power per stack

const default_leach := 0.05     # 5% of damage

func get_tooltip_stats() -> String:
    return "Heals %d%% of dealt damage" % int(round(default_leach * 100.0))

func attachEventManager(em: Node):
    _cache_holder(em)
    event_manager.subscribe(trigger_event, Callable(self, "_on_event"))

func _on_event(event: Dictionary):
    var health: Health = get_health()
    if not health:
        return
    var dc: DamageContext = event.get("damage_context")
    var stacks_multiplier = 1.0 + (bonus_per_stack * (_active_stacks() - 1)) # +20% per stack
    var leach_amount = default_leach * dc.final_amount
    health.heal(leach_amount * stacks_multiplier)