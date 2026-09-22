# base_modifier.gd
## Base class for every effect modifier in Systems/Items/Modifiers/.
##
## Owns the single source of truth for the stack bookkeeping contract and the
## common attachment plumbing so subclasses only carry their own trigger logic.
##
## Subclasses:
## - declare their own @export tuning values, display contract and per-stack math
## - implement `attachEventManager(em)` which caches the holder via
##   `_cache_holder(em)` and subscribes to the events they need
extends Node
class_name BaseModifier

var event_manager: EventManager = null
var holder: Node = null
var stats: Stats = null
var stacks: Array[bool] = []  # each entry = active/inactive

func _active_stacks() -> int:
	return max(1, stacks.count(true))

func add_stack(active: bool):
	stacks.append(active)
	_on_stacks_changed()

func remove_stack(index: int):
	if index >= 0 and index < stacks.size():
		stacks.remove_at(index)
	_on_stacks_changed()

func set_stack_active(index: int, active: bool):
	if index >= 0 and index < stacks.size():
		stacks[index] = active
	_on_stacks_changed()

## Override to react to stack bookkeeping (e.g. EnergyShield recomputes its cap).
func _on_stacks_changed() -> void:
	pass

## Cache `event_manager`, `holder` and `stats` for the entity this modifier is
## attached to. Called from each subclass's `attachEventManager`.
func _cache_holder(em: Node) -> void:
	event_manager = em
	holder = em.get_parent() if em else null
	stats = holder.get_node_or_null("Stats") if holder else null
	if not stats:
		var holder_name := str(holder.name) if holder else "<none>"
		push_warning("%s: Stats node not found under holder %s" % [name, holder_name])

## The holder's Health node, or null when it is missing.
func get_health() -> Health:
	if not holder or not is_instance_valid(holder):
		return null
	return holder.get_node_or_null("Health") as Health