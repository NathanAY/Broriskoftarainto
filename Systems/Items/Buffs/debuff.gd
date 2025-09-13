# Debuff.gd
extends Node
class_name Debuff

@export var trigger_event: String = "after_deal_damage"    # event name to listen for
@export var duration: float = 3.0               # how long buff lasts
@export var modifiers: Dictionary = {           # stat changes
    "armor": {"flat": -10, "percent": -0.01}
}

var holder: Node = null
var target_stats: Stats = null
var event_manager: EventManager = null

func _ready():
    holder = get_parent().hold_owner
    if not holder:
        push_warning("Debuff has no parent/holder!")
        return

    event_manager = holder.get_node_or_null("EventManager")


    # Subscribe to the trigger event
    event_manager.subscribe(trigger_event, Callable(self, "_on_trigger"))

func _on_trigger(event: Dictionary):
    var ctx: DamageContext = event["damage_context"]
    target_stats = ctx.target.get_node_or_null("Stats")
    if not target_stats:
        return

    # Apply buff modifiers
    target_stats.add_modifier(modifiers)

    # Setup timer to remove after duration
    var t := Timer.new()
    t.wait_time = duration
    t.one_shot = true
    t.timeout.connect(_on_expire.bind(t))
    add_child(t)
    t.start()

func _on_expire(t: Timer):
    if target_stats:
        target_stats.remove_modifier(modifiers)
    t.queue_free()
