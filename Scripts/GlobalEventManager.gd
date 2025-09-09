#LocalEventManager.gd
extends Node

var listeners: Dictionary = {}

#event_manager.subscribe("on_kill", Callable(self, "_on_projectile_hit"))
func subscribe(event_name: String, listener: Callable) -> void:
    if not listeners.has(event_name):
        listeners[event_name] = []
    listeners[event_name].append(listener)

func unsubscribe(event_name: String, listener: Callable) -> void:
    if listeners.has(event_name):
        listeners[event_name].erase(listener)

#event_manager.emit_event("on_kill", [self, body])
func emit_event(event_name: String, args: Array = []) -> void:
    if listeners.has(event_name):
        for l in listeners[event_name]:
            l.callv(args)

#on_kill
