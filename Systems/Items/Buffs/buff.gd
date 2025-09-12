# Buff.gd
extends Node
class_name Buff

@export var trigger_event: String = "on_hit"    # event name to listen for
@export var duration: float = 3.0               # how long buff lasts
@export var modifiers: Dictionary = {           # stat changes
    "attack_speed": {"flat": 0.0, "percent": 0.5}
}

var holder: Node = null
var stats: Stats = null
var event_manager: EventManager = null

func _ready():
    holder = get_parent().hold_owner
    if not holder:
        push_warning("Buff has no parent/holder!")
        return

    stats = holder.get_node_or_null("Stats")
    event_manager = holder.get_node_or_null("EventManager")

    if not stats or not event_manager:
        push_warning("Buff: missing Stats or EventManager on holder!")
        queue_free()
        return

    # Subscribe to the trigger event
    event_manager.subscribe(trigger_event, Callable(self, "_on_trigger"))

func _on_trigger(event_data):
    if not stats:
        return

    # Apply buff modifiers
    stats.add_modifier(modifiers)

    # Setup timer to remove after duration
    var t := Timer.new()
    t.wait_time = duration
    t.one_shot = true
    t.timeout.connect(_on_expire)
    add_child(t)
    t.start()

func _on_expire():
    if stats:
        stats.remove_modifier(modifiers)
