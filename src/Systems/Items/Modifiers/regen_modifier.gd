extends BaseModifier

@export var display_name: String = "Regen"
@export var interval: float = 0.5      # seconds

## Passive timer-based regen (no trigger). Subclasses supply the amount via
## `_heal_per_tick(h)` and their own `get_tooltip_stats()` fragment.
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
        h.heal(_heal_per_tick(h) * _active_stacks())

## Heal amount healed per tick; implemented by subclasses (flat or % max HP).
func _heal_per_tick(_h: Health) -> float:
    return 0.0