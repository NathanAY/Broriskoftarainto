## The damage pipeline and the rules every hit obeys. See docs/systems/damage.md.
##
## `deal()` is the attacker half and the only way to hurt something;
## `Health.apply_damage()` is the defender half it calls. Crit and armor are
## core steps here, read straight from `Stats` - no item effect switches them on.
class_name Damage
extends RefCounted

## Listener phases for `EventManager.subscribe(event, listener, phase)`. Lower
## runs first, equal phases run in subscription order. A listener that changes
## `final_amount` picks the phase that says *how*, so the result never depends
## on which item was bought first.
const PHASE_MODIFY := 0        # grow or shrink the hit (bonus damage); the default
const PHASE_MITIGATE := 100    # block or reduce it (front shield)
const PHASE_ABSORB := 200      # soak what is left (energy shield)
const PHASE_OBSERVE := 1000    # read the settled number (visuals, triggered effects)


## Run one hit through the whole pipeline. `bus` is the attacker's EventManager
## (null for damage with no attacker). Returns true when the hit landed.
##
## Order: `before_deal_damage` -> crit roll -> `Health.apply_damage()` (armor ->
## `before_take_damage` -> subtract -> `on_death` -> `after_take_damage`) ->
## `after_deal_damage` -> `on_hit` (direct hits only) -> `on_kill`.
static func deal(ctx: DamageContext, bus: EventManager) -> bool:
	var health := _health_of(ctx.target)
	if health == null:
		return false
	if bus != null:
		if ctx.attacker == null:
			ctx.attacker = bus.get_parent()
		bus.emit_event("before_deal_damage", {"damage_context": ctx})
		_roll_crit(ctx, bus)
	if not health.apply_damage(ctx):
		return false
	if bus != null:
		bus.emit_event("after_deal_damage", {"damage_context": ctx})
		# A direct hit is one a weapon landed. Explosions, orbs, poison ticks and
		# modifier-spawned projectiles carry no weapon, so they never proc
		# on-hit effects and cannot chain into more of themselves.
		if ctx.weapon != null:
			bus.emit_event("on_hit", {"damage_context": ctx})
		if health.is_dead:
			bus.emit_event("on_kill", {"damage_context": ctx})
	return true


## Damage left after `armor`: 10 armor halves a hit, negative armor amplifies it.
static func armor_multiplier(armor: float) -> float:
	if armor >= 0.0:
		return 10.0 / (10.0 + armor)
	return 1.0 - armor / 10.0


## The defender's armor step, run by `Health.apply_damage()` before any
## `before_take_damage` listener. Every armor source sums into the one stat, so
## a hit is reduced exactly once.
static func apply_armor(ctx: DamageContext, stats: Stats) -> void:
	if stats == null:
		return
	ctx.final_amount *= armor_multiplier(stats.get_stat("armor"))


static func _roll_crit(ctx: DamageContext, bus: EventManager) -> void:
	if not ctx.can_crit or not is_instance_valid(ctx.attacker):
		return
	var stats := ctx.attacker.get_node_or_null("Stats") as Stats
	if stats == null or randf() * 100.0 >= stats.get_stat("critical_chance"):
		return
	ctx.final_amount *= stats.get_stat("critical_multiplier")
	ctx.is_crit = true
	bus.emit_event("on_crit", {"damage_context": ctx})


static func _health_of(target: Node) -> Health:
	if not is_instance_valid(target):
		return null
	return target.get_node_or_null("Health") as Health
