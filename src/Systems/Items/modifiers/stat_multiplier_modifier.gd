extends BaseModifier

@export var display_name: String = "Stat Multiplier"
@export var trigger_event: String = "on_item_added"

# Configurable parameters
@export var target_stat: String = "damage"
@export var multiplier: float = 2.0

func get_tooltip_stats() -> String:
    return "Multiplies %s bonuses from items by %sx per stack" % [target_stat, str(multiplier)]

func attachEventManager(em: Node):
    _cache_holder(em)
    # Subscribe to item additions to intercept stat modifiers
    event_manager.subscribe(trigger_event, Callable(self, "_on_item_added"))

func _on_item_added(event):
    var item = event["item"]
    
    # Check if this item modifies the target stat
    if item.modifiers.has(target_stat):
        var mod_data = item.modifiers[target_stat]
        
        # Modify the flat bonus if it exists
        if mod_data is Dictionary and mod_data.has("flat"):
            # Apply multiplier (scales with stacks)
            mod_data["flat"] = mod_data["flat"] * multiplier * _active_stacks()