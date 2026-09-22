extends BaseModifier

@export var display_name: String = "Regen"
@export var heal_amount: float = 4.0   # heal per tick
@export var heal_amount_percent: float = 0.01   # heal% of max life per tick
@export var interval: float = 0.5      # seconds

## Passive timer-based regen (no trigger). Dynamic fragment so generated
## values are always shown, never stale static text.
func get_tooltip_stats() -> String:
    return "Regenerates %s HP + %d%% max HP every %ss" % [str(heal_amount), int(round(heal_amount_percent * 100.0)), str(interval)]

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
        h.heal((heal_amount + (h.max_health * heal_amount_percent)) * _active_stacks())