extends BaseModifier

@export var display_name: String = "Regen"
@export var interval: float = 0.5      # seconds

## Passive timer-based health change (no trigger). Subclasses supply the SIGNED
## amount via `_health_delta_per_tick(h)` and their own `get_tooltip_stats()`
## fragment. A positive value heals, a negative one drains.
##
## The two halves cannot share one `Health` entry point. `Health.heal()` clamps
## only at the ceiling (`min(current + amount, max)`) and never checks for
## death, so feeding it a negative amount would drive health below zero while
## the entity stayed alive forever, and would fire `on_heal` with a negative
## payload that every heal listener would read as a gain. A drain therefore
## goes through `Health.apply_damage()`, which owns the whole defender phase
## (`before_take_damage` -> armor / energy shield -> damage -> `on_death` ->
## `after_take_damage`) and is the only place the dead check lives.
var _regen_timer: Timer

func attachEventManager(em: EventManager):
    _cache_holder(em)

    # setup regen timer
    _regen_timer = Timer.new()
    _regen_timer.wait_time = interval
    _regen_timer.autostart = true
    _regen_timer.one_shot = false
    _regen_timer.timeout.connect(_on_regen_tick)
    add_child(_regen_timer)

func _on_regen_tick():
    if stacks.is_empty():
        return
    var h: Health = get_health()
    if h:
        _apply_health_delta(h, _health_delta_per_tick(h) * _active_stacks())

## Signed health change per tick; implemented by subclasses (flat or % max HP).
## Negative values drain - see the routing note above.
func _health_delta_per_tick(_h: Health) -> float:
    return 0.0

## Apply a signed health delta through whichever `Health` entry point is correct
## for its sign. Exactly zero is a no-op: healing by 0 would still emit
## `on_heal`, and damaging by 0 would still flash and float a damage number.
func _apply_health_delta(h: Health, amount: float) -> void:
    if amount > 0.0:
        h.heal(amount)
    elif amount < 0.0:
        _drain_health(h, -amount)

## Deal `amount` health to the holder itself, with no attacker behind it.
##
## Nothing is emitted on an attacker's bus (`before_deal_damage`,
## `after_deal_damage`, `on_kill`): there is no source to emit them on but the
## holder's own, and a self-inflicted tick must not pay the holder its own
## `StatOnKillModifier` rewards for dying. The defender phase comes for free
## because `Health.apply_damage` emits it on the holder's bus.
func _drain_health(h: Health, amount: float) -> void:
    var ctx := DamageContext.new()
    ctx.source = holder
    ctx.target = holder
    ctx.base_amount = amount
    ctx.final_amount = amount
    ctx.damage_type = "drain"
    ctx.tags.append("life_drain")
    h.apply_damage(ctx)
