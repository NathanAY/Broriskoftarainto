extends Node
class_name Buff

@export var trigger_event: String = "on_hit"
@export var duration: float = 3.0
@export var max_stacks: int = 10
@export var modifiers: Dictionary = {
    #"attack_speed": {"flat": 0.15, "percent": 0.2}
    "attack_speed": {"flat": 0.5}
}

var holder: Node = null
var stats: Stats = null
var event_manager: EventManager = null
var _active_stacks: Array = []  # each = { "timer": Timer, "id": int }

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

    event_manager.subscribe(trigger_event, Callable(self, "_on_trigger"))

func _on_trigger(event_data):
    if not stats:
        return

    # If we're at max stacks, remove oldest first (to make space)
    if _active_stacks.size() >= max_stacks:
        var oldest = _active_stacks.pop_front()
        _expire_stack(oldest)

    # Apply new stack
    stats.add_modifier(modifiers)

    var id = randi()
    var t := Timer.new()
    t.wait_time = duration
    t.one_shot = true
    t.timeout.connect(_on_expire.bind(id))
    add_child(t)
    t.start()

    _active_stacks.append({"timer": t, "id": id})
    event_manager.emit_event("on_buff_added", [{"buff": self, "holder": holder, "id": id}])

func _on_expire(id: int):
    # Find and remove expired stack
    for stack in _active_stacks:
        if stack["id"] == id:
            _active_stacks.erase(stack)
            _expire_stack(stack)
            break

func _expire_stack(stack: Dictionary):
    if stats:
        stats.remove_modifier(modifiers)
    event_manager.emit_event("on_buff_removed", [{
        "buff": self,
        "holder": holder,
        "id": stack["id"],
        "stacks": _active_stacks.size()
    }])
    if stack.has("timer"):
        stack["timer"].queue_free()
