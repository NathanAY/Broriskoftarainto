extends Node
class_name StatMultiplierModifier

var event_manager: EventManager = null
var holder: Node = null
var stats: Stats = null

# Configurable parameters
@export var target_stat: String = "damage"
@export var multiplier: float = 2.0

func attachEventManager(em: Node):
    event_manager = em
    holder = em.get_parent()
    stats = holder.get_node("Stats")
    
    # Subscribe to item additions to intercept stat modifiers
    em.subscribe("on_item_added", Callable(self, "_on_item_added"))

func _on_item_added(event):
    var item = event["item"]
    
    # Check if this item modifies the target stat
    if item.modifiers.has(target_stat):
        var mod_data = item.modifiers[target_stat]
        
        # Modify the flat bonus if it exists
        if mod_data is Dictionary and mod_data.has("flat"):
            var original_flat = mod_data["flat"]
            
            # Apply multiplier
            mod_data["flat"] = original_flat * multiplier
            print("StatMultiplierModifier: Multiplied %s item from %s to %s" % [target_stat, original_flat, mod_data["flat"]])
