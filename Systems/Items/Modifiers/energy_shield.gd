extends Node
class_name Shield

var max_shield: float = 0.0
@export var recharge_rate: float = 10.0         # per second
@export var recharge_delay: float = 1.5         # seconds after last damage
var current_shield: float = 0.0
var _time_since_damage: float = 0.0

var stats: Stats = null
var event_manager: EventManager = null

func attachEventManager(em: Node):
    event_manager = em
    stats = em.get_parent().get_node_or_null("Stats")
    if not stats:
        push_warning("Energy shiel: Stats not found on holder %s" % em.get_parent())
        return
    #current_shield = max_shield
    _update_max_shield([])
    if event_manager:
        event_manager.subscribe("before_take_damage", Callable(self, "_on_before_take_damage"))
        event_manager.subscribe("on_stat_changes", Callable(self, "_update_max_shield"))

func _process(delta: float) -> void:
    if current_shield < max_shield:
        _time_since_damage += delta
        if _time_since_damage >= recharge_delay:
            var amount = recharge_rate * delta
            current_shield = min(current_shield + amount, max_shield)
            _emit_shield_changed(amount)

func _on_before_take_damage(event):
    var ctx: DamageContext = event["damage_context"]
    if not ctx:
        return

    if current_shield > 0:
        var damage_absorbed = min(current_shield, ctx.final_amount)
        current_shield -= damage_absorbed
        ctx.final_amount -= damage_absorbed
        ctx.energy_shield_absorbed = damage_absorbed
        _time_since_damage = 0.0  # reset recharge timer
        _emit_shield_changed(-damage_absorbed)

func _update_max_shield(event):
    if stats:
        max_shield = stats.get_stat("energy_shield")
        current_shield = min(current_shield, max_shield)
        _emit_shield_changed(0)

func _emit_shield_changed(amount: float):
    if event_manager:
        event_manager.emit_event("on_shield_changed", [{"self": get_parent(), "amount": amount,
         "current_shield": current_shield, "max_shield": max_shield}])
