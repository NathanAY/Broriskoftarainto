#LocalEventManager.gd
extends Node
class_name EventManager

var listeners: Dictionary = {}

#event_manager.subscribe("on_hit", Callable(self, "_on_hit"))
func subscribe(event_name: String, listener: Callable) -> void:
    if not listeners.has(event_name):
        listeners[event_name] = []
    listeners[event_name].append(listener)

func unsubscribe(event_name: String, listener: Callable) -> void:
    if listeners.has(event_name):
        listeners[event_name].erase(listener)

#event_manager.emit_event("on_hit", [self, body])
func emit_event(event_name: String, args: Array = []) -> void:
    if listeners.has(event_name):
        for l in listeners[event_name]:
            l.callv(args)

#on_stat_changes
#on_item_added
#on_item_removed

#on_attack
#on_hit

#on_debuff_added
#on_debuff_removed
#on_buff_added
#on_buff_removed

#before_deal_damage damage_context, body
#after_deal_damage damage_context, body
#before_take_damage damage_context, body
#on_death
#on_health_changed
