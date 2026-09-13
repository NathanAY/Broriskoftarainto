#LocalEventManager.gd
extends Node
class_name EventManager

var listeners: Dictionary = {}

#event_manager.subscribe("on_hit", Callable(self, "_on_hit"))
func subscribe(event_name: String, listener: Callable) -> EventContracts.CheckResult:
	var result := EventContracts.check_subscribe(event_name, listener)
	if not result.ok:
		EventContracts.report(result)
		return result
	if not listeners.has(event_name):
		listeners[event_name] = []
	listeners[event_name].append(listener)
	return result

func unsubscribe(event_name: String, listener: Callable) -> void:
	if listeners.has(event_name):
		listeners[event_name].erase(listener)

#event_manager.emit_event("on_hit", {"body": body, "damage_context": ctx})
func emit_event(event_name: String, payload: Variant) -> EventContracts.CheckResult:
	var result := EventContracts.check_emit(event_name, payload)
	if not result.ok:
		EventContracts.report(result)
		return result
	if listeners.has(event_name):
		for l in listeners[event_name]:
			l.call(payload)
	return result