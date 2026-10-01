extends BaseModifier
class_name StatOnKillModifier

@export var display_name: String = "Stat On Kill"
@export var trigger_event: String = "on_kill"
@export var target_stat: String = "health"
@export var add_amount: float = 1.0

func get_tooltip_stats() -> String:
    var amount_text := str(int(round(add_amount))) if is_equal_approx(add_amount, round(add_amount)) else str(add_amount)
    return "Gain %s %s per stack" % [amount_text, target_stat]

## Generation-time hook (called by ItemFactory): roll a random stat from the
## Stats table so generated items cover different options (health on kill,
## movement_speed on kill, ...) and scale the amount to the stat's base value.
## Context: {"rng": RandomNumberGenerator, "stats": Dictionary}.
## Returns true when this instance was mutated (factory repacks it).
func randomize_for_generation(context: Dictionary) -> bool:
    var available: Dictionary = context.get("stats", {})
    if available.is_empty():
        return false
    var rng: RandomNumberGenerator = context.get("rng")
    var stat_names: Array = available.keys()
    var chosen: String = str(stat_names[rng.randi_range(0, stat_names.size() - 1)]) if rng != null else str(stat_names.pick_random())
    target_stat = chosen
    add_amount = _scaled_amount_for(chosen, float(available.get(chosen, 0.0)), rng)
    return true

## Suffix so generated items with different stats are distinguishable
## (e.g. "Stat On Kill Modifier (movement_speed)").
func get_generation_suffix() -> String:
    if target_stat.is_empty():
        return ""
    return " (%s)" % target_stat

## Same 5-10% of base value rule the factory uses for stat items.
func _scaled_amount_for(_stat_name: String, base_value: float, rng: RandomNumberGenerator) -> float:
    if is_equal_approx(base_value, 0.0):
        return 1.0
    var fraction := 0.075
    if rng != null:
        fraction = rng.randf_range(0.05, 0.1)
    return float("%.2f" % [base_value * fraction])

func attachEventManager(em: Node):
    _cache_holder(em)
    event_manager.subscribe(trigger_event, Callable(self, "_on_event"))

func _on_event(_event: Dictionary):
    if not stats:
        return
    if not stats.stats.has(target_stat):
        return
    var total = add_amount * _active_stacks()
    stats.set_base_stat(target_stat, float(stats.stats.get(target_stat)) + total)
