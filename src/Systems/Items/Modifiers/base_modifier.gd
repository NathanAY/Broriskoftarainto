# base_modifier.gd
## Base class for every effect modifier in Systems/Items/modifiers/.
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

## When non-null, handler events must carry this exact weapon to fire.
## Weapon built-in modifiers bind to their owning weapon instance; item-pickup
## modifiers leave it null (holder-wide, unchanged behavior).
var bound_weapon: Object = null

## Optional stat this modifier owns on the holder's Stats.
##
## The stat is dynamic: it exists while at least one modifier instance of this
## type (`provided_stat_owned = true`) is attached and is erased (reference-
## counted) when the last one detaches. The modifier only ever READS the stat
## through `get_provided_stat()`; it never writes it. That way stat items / buffs /
## debuffs compose with whatever the modifier installs, and can drive the value
## negative. Empty string = this modifier provides nothing.
@export var provided_stat: String = ""

## Base value installed on first claim of the owned stat (e.g. lifesteal base 1.0
## as a multiplier). Ignored for non-owned stats.
@export var provided_stat_default: float = 0.0

## True = dynamic presence: claim on attach, release (erase) on last detach.
## False = the stat already exists on the holder (e.g. armor); the modifier is a
## pure consumer and never claims/releases it.
@export var provided_stat_owned: bool = true

# Tracked subscriptions so detach can unregister before freeing (the bus crashes
# on freed listeners). Each entry: [event_name, callable].
var _subscriptions: Array = []

## Subscribe and record the pair. When this modifier is bound to a weapon
## (`bound_weapon != null`), the listener is auto-wrapped so it only reacts to
## events from that weapon. That way per-handler `_is_bound_event` guards are
## unnecessary: any modifier that subscribes via `_subscribe` is correctly scoped
## the moment a weapon binds it. Unbound modifiers (item-pickup path) get the raw
## listener with zero behavior change.
func _subscribe(event_name: String, listener: Callable) -> void:
	var effective := listener
	if bound_weapon != null:
		effective = Callable(self, "_guard_weapon_event").bind(listener)
	_subscriptions.append([event_name, effective])
	if event_manager:
		event_manager.subscribe(event_name, effective)

## Bound-listener wrapper: forwards `data` to the wrapped listener only when the
## event belongs to the bound weapon (or the modifier is unbound).
func _guard_weapon_event(data: Dictionary, listener: Callable) -> void:
	if _is_bound_event(data):
		listener.call(data)

func _unsubscribe_all() -> void:
	for sub in _subscriptions:
		if is_instance_valid(event_manager):
			event_manager.unsubscribe(sub[0], sub[1])
	_subscriptions.clear()

## True when this modifier may react to an event payload. Unbound modifiers
## react to everything; bound ones only to events from their weapon.
func _is_bound_event(data: Dictionary) -> bool:
	if bound_weapon == null:
		return true
	return data.get("weapon") == bound_weapon

func _active_stacks() -> int:
	return max(1, stacks.count(true))

func add_stack(active: bool):
	stacks.append(active)
	_on_stacks_changed()

func remove_stack(index: int):
	if index >= 0 and index < stacks.size():
		stacks.remove_at(index)
	_on_stacks_changed()
	if stacks.is_empty():
		detach()

func set_stack_active(index: int, active: bool):
	if index >= 0 and index < stacks.size():
		stacks[index] = active
	_on_stacks_changed()

## Remove the most recently added stack. Used by `ItemHolder.remove_item`, which
## does not track which item instance maps to which stack index.
func remove_latest_stack():
	remove_stack(stacks.size() - 1)

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
	_claim_provided_stat()

## Live value of `provided_stat` to read in behavior handlers. Falls back to
## `provided_stat_default` when there is no Stats node yet.
func get_provided_stat() -> float:
	if provided_stat.is_empty() or not stats:
		return provided_stat_default
	return stats.get_stat(provided_stat)

## Claim the owned stat on the holder's Stats (first claim installs the base).
## Non-owning modifiers (e.g. armor) skip this — their stat already exists.
func _claim_provided_stat() -> void:
	if provided_stat.is_empty() or not stats or not provided_stat_owned:
		return
	stats.claim_provided_stat(provided_stat, provided_stat_default)

## Release the owned stat. Erases the key when the last claiming modifier detaches.
func _release_provided_stat() -> void:
	if provided_stat.is_empty() or not stats or not provided_stat_owned:
		return
	stats.release_provided_stat(provided_stat)

## Full detach: release the owned stat and unsubscribe all recorded subscriptions.
## Called by `remove_stack` when the last stack is removed; lifecycle owners
## (ItemHolder) may also call it directly before freeing the node.
func detach() -> void:
	_release_provided_stat()
	_unsubscribe_all()

## The holder's Health node, or null when it is missing.
func get_health() -> Health:
	if not holder or not is_instance_valid(holder):
		return null
	return holder.get_node_or_null("Health") as Health


# -------------------
# Scene -> live effect
# -------------------
## The single place an effect scene becomes a live node under a host. Hosts
## (character spawn, item pickup, ...) forward the scene they were handed
## instead of re-implementing instantiate/add_child.
##
## Wiring is left to the caller on purpose: the effect kinds wire differently
## (a BaseModifier through `attachEventManager`, a Buff/poison effect in its own
## `_ready` from its ItemHolder parent), so this helper only creates.
static func instantiate_attached(scene: PackedScene, parent: Node) -> Node:
	if scene == null or parent == null:
		return null
	var instance: Node = scene.instantiate()
	if instance == null:
		return null
	parent.add_child(instance)
	return instance


## The complete contract for a BaseModifier scene: instantiate under `parent`,
## `attachEventManager(em)`, one active stack. This is what a host that declares
## modifier scenes uses (a character listing them in `CharacterData.modifiers`),
## so a declaration that is not a modifier scene fails loudly with a warning
## instead of silently doing nothing.
##
## A modifier without an event manager can never react to anything, so a null
## `em` also warns and returns null rather than handing back a dead node.
static func attach(scene: PackedScene, parent: Node, em: EventManager) -> BaseModifier:
	var path := str(scene.resource_path) if scene != null else "<null>"
	if em == null:
		push_warning("BaseModifier.attach: no EventManager to wire %s to" % [path])
		return null
	var node := instantiate_attached(scene, parent)
	if not (node is BaseModifier):
		push_warning("BaseModifier.attach: %s is not a BaseModifier scene" % [path])
		if is_instance_valid(node):
			node.free()
		return null
	var instance := node as BaseModifier
	instance.attachEventManager(em)
	instance.add_stack(true)
	return instance