# A charger: it walks in, stops to telegraph, then drives along the direction
# it locked at the end of the windup.
#
# The charge speed is a temporary `Stats` boost rather than a velocity, because
# `Enemy._physics_process` clamps the velocity to
# `stats.get_movement_speed_px()` after the behaviour has run. A behaviour that
# simply set `velocity = direction * 400` would be clamped straight back to
# walk speed.
extends MovementBehaviour
class_name ChargeMovementBehaviour

enum ChargeState {
    APPROACH,  ## walk to within `stop_distance`
    WINDUP,    ## stand still and face the player
    CHARGE,    ## drive along the locked direction
    RECOVER,   ## stand still, then back to APPROACH
}

## How close the creature gets before it stops to telegraph.
@export var stop_distance: float = 140.0
## How long the telegraph lasts, in seconds.
@export var windup_time: float = 0.5
## How long the charge drives, in seconds.
@export var charge_duration: float = 0.45
## How long the creature stands still after the charge, in seconds.
@export var recover_time: float = 0.4
## Movement speed multiplier while charging.
@export var charge_speed_scale: float = 3.0

## The state the charger is in right now.
var state: int = ChargeState.APPROACH

var _state_timer: float = 0.0
## The direction locked at the end of the windup. It is not re-aimed during the
## charge: a charge that tracks the player is just a fast walk, and the player
## has to be able to dodge it.
var _charge_direction: Vector2 = Vector2.RIGHT
## The stat modifier carrying the charge speed boost. Kept so it can be taken
## off again - a charger that died mid-charge would otherwise leave a corpse
## with a movement speed three times its design value.
var _boost: Dictionary = {}
var _boosted: bool = false
## The creature this behaviour drives, held so the death handler can take the
## boost off without a second argument.
var _owner: CharacterBody2D = null
var _subscribed_to_death: bool = false


func process_movement(creature_self: CharacterBody2D, delta: float) -> void:
    _owner = creature_self
    _subscribe_to_owner_death(creature_self)
    var node = creature_self.target
    if not node:
        return
    match state:
        ChargeState.APPROACH:
            _approach(creature_self, node)
        ChargeState.WINDUP:
            _windup(creature_self, node, delta)
        ChargeState.CHARGE:
            _charge(creature_self, delta)
        ChargeState.RECOVER:
            _recover(creature_self, delta)


## Walks towards the target until it is close enough to start the windup.
func _approach(creature_self: CharacterBody2D, node: Node) -> void:
    var to_target: Vector2 = node.global_position - creature_self.global_position
    if to_target.length() <= stop_distance:
        creature_self.velocity = Vector2.ZERO
        creature_self.anim_player.play("idle")
        _enter(creature_self, ChargeState.WINDUP)
        return
    var direction := to_target.normalized()
    creature_self.velocity = direction * creature_self.stats.get_movement_speed_px()
    creature_self.anim_player.play("move")
    creature_self.sprite.flip_h = direction.x < 0


## Stands still and faces the player. The direction is locked when the windup
## ends, not when it starts, so a player who moves during the telegraph still
## gets dodged.
func _windup(creature_self: CharacterBody2D, node: Node, delta: float) -> void:
    creature_self.velocity = Vector2.ZERO
    creature_self.anim_player.play("idle")
    var to_target: Vector2 = node.global_position - creature_self.global_position
    if to_target.length() > 0.001:
        creature_self.sprite.flip_h = to_target.x < 0
    _state_timer += delta
    if _state_timer >= windup_time:
        if to_target.length() > 0.001:
            _charge_direction = to_target.normalized()
        _enter(creature_self, ChargeState.CHARGE)


## Drives along the locked direction, ignoring the target.
func _charge(creature_self: CharacterBody2D, delta: float) -> void:
    creature_self.velocity = _charge_direction * creature_self.stats.get_movement_speed_px()
    creature_self.anim_player.play("move")
    _state_timer += delta
    if _state_timer >= charge_duration:
        _enter(creature_self, ChargeState.RECOVER)


## Stands still after the charge, then goes back to walking.
func _recover(creature_self: CharacterBody2D, delta: float) -> void:
    creature_self.velocity = Vector2.ZERO
    creature_self.anim_player.play("idle")
    _state_timer += delta
    if _state_timer >= recover_time:
        _enter(creature_self, ChargeState.APPROACH)


func _enter(creature_self: CharacterBody2D, next_state: int) -> void:
    state = next_state
    _state_timer = 0.0
    if next_state == ChargeState.CHARGE:
        _apply_boost(creature_self)
    elif next_state == ChargeState.RECOVER:
        _remove_boost(creature_self)


## Puts the charge speed on as a stat modifier, so the enemy speed clamp in
## `Enemy._physics_process` lets the charger through at charge speed.
func _apply_boost(creature_self: CharacterBody2D) -> void:
    if _boosted:
        return
    var creature_stats := creature_self.stats as Stats
    if creature_stats == null:
        return
    _boost = {"movement_speed": {"percent": charge_speed_scale - 1.0}}
    creature_stats.add_modifier(_boost)
    _boosted = true


## Takes the charge speed back off. Safe to call when there is no boost.
func _remove_boost(creature_self: CharacterBody2D) -> void:
    if not _boosted:
        return
    _boosted = false
    var creature_stats := creature_self.stats as Stats
    if creature_stats != null and not _boost.is_empty():
        creature_stats.remove_modifier(_boost)
    _boost = {}


## Watches the creature's own event bus for its death, so the boost comes off
## on that path too. `Enemy` stops moving a corpse, but the stat outlives it.
func _subscribe_to_owner_death(creature_self: CharacterBody2D) -> void:
    if _subscribed_to_death:
        return
    var bus := creature_self.get_node_or_null("EventManager") as EventManager
    if bus == null:
        return
    bus.subscribe("on_death", Callable(self, "_on_owner_died"))
    _subscribed_to_death = true


func _on_owner_died(_event: Dictionary) -> void:
    if _owner == null or not is_instance_valid(_owner):
        return
    _remove_boost(_owner)
