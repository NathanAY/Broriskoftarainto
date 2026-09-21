extends Node
class_name StatMultiplierModifier

var event_manager: EventManager = null
var holder: Node = null
var stats: Stats = null
var stacks: Array[bool] = []  # each entry = active/inactive

@export var display_name: String = "Stat Multiplier"
@export var trigger_event: String = "on_item_added"

# Configurable parameters
@export var target_stat: String = "damage"
@export var multiplier: float = 2.0

func get_tooltip_stats() -> String:
    return "Multiplies %s bonuses from items by %sx per stack" % [target_stat, str(multiplier)]

func _active_stacks() -> int:
    return max(1, stacks.count(true))

func add_stack(active: bool):
    stacks.append(active)

func remove_stack(index: int):
    if index >= 0 and index < stacks.size():
        stacks.remove_at(index)

func set_stack_active(index: int, active: bool):
    if index >= 0 and index < stacks.size():
        stacks[index] = active

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
            
            # Apply multiplier (scales with stacks)
            mod_data["flat"] = original_flat * multiplier * _active_stacks()
            print("StatMultiplierModifier: Multiplied %s item from %s to %s" % [target_stat, original_flat, mod_data["flat"]])