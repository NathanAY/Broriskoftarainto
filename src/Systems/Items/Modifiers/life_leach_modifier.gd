extends BaseModifier

@export var display_name: String = "Life Leach"
@export var trigger_event: String = "on_hit"

const LIFESTEAL_PER_STACK := 0.05   # 5% of damage per item


func _init():
	provided_stat = "lifeleach"
	provided_stat_default = 1.0
	provided_stat_owned = true

func get_tooltip_stats() -> String:
	return "Heals %d%% of dealt damage per item" % int(round(LIFESTEAL_PER_STACK * 100.0))

func attachEventManager(em: Node):
	_cache_holder(em)
	event_manager.subscribe(trigger_event, Callable(self, "_on_event"))

func _on_event(event: Dictionary):
	var health: Health = get_health()
	if not health:
		return
	var dc: DamageContext = event.get("damage_context")
	var leach_ratio := LIFESTEAL_PER_STACK * _active_stacks() * get_provided_stat()
	health.heal(dc.final_amount * leach_ratio)