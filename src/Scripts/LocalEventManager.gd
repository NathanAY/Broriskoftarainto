#LocalEventManager.gd
extends Node
class_name EventManager

var listeners: Dictionary = {}
## Parallel to `listeners`: each listener's phase, kept sorted ascending.
var _phases: Dictionary = {}

## `phase` orders listeners of one event (lower first, ties in subscription
## order). Damage listeners use the `Damage.PHASE_*` constants.
#event_manager.subscribe("on_hit", Callable(self, "_on_hit"))
func subscribe(event_name: String, listener: Callable, phase: int = 0) -> EventContracts.CheckResult:
    var result := EventContracts.check_subscribe(event_name, listener)
    if not result.ok:
        EventContracts.report(result)
        return result
    var calls: Array = listeners.get_or_add(event_name, [])
    var phases: Array = _phases.get_or_add(event_name, [])
    var at := phases.bsearch(phase, false)
    calls.insert(at, listener)
    phases.insert(at, phase)
    return result

func unsubscribe(event_name: String, listener: Callable) -> void:
    if not listeners.has(event_name):
        return
    var at: int = listeners[event_name].find(listener)
    if at != -1:
        listeners[event_name].remove_at(at)
        _phases[event_name].remove_at(at)

#event_manager.emit_event("on_hit", {"damage_context": ctx})
func emit_event(event_name: String, payload: Variant) -> EventContracts.CheckResult:
    var result := EventContracts.check_emit(event_name, payload)
    if not result.ok:
        EventContracts.report(result)
        return result
    if listeners.has(event_name):
        for l in listeners[event_name]:
            l.call(payload)
    return result
