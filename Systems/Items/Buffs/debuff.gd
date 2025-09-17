# Debuff.gd
extends Node
class_name Debuff

@export var trigger_event: String = "after_deal_damage"    # event name to listen for
@export var duration: float = 3.0               # how long buff lasts
@export var modifiers: Dictionary = {           # stat changes
    "armor": {"flat": -10, "percent": -0.01}
}

var holder: Node = null
var holder_em: EventManager = null

var target: Node = null
var target_stats: Stats = null
var target_em: EventManager = null

func _ready():
    holder = get_parent().hold_owner
    if not holder:
        push_warning("Debuff has no parent/holder!")
        return

    holder_em = holder.get_node_or_null("EventManager")

    # Subscribe to the trigger event
    holder_em.subscribe(trigger_event, Callable(self, "_on_trigger"))

func _on_trigger(event: Dictionary):
    var ctx: DamageContext = event["damage_context"]
    target = ctx.target
    target_stats = target.get_node_or_null("Stats")
    target_em = target.get_node_or_null("EventManager")
    if not target_stats:
        return
   
    # Apply debuff
    target_stats.add_modifier(modifiers)
    
    # Emit event so UI/logic can react
    var id: int = randi()
    target_em.emit_event("on_debuff_added", [{"debuff": self, "holder": holder, "target": target, "id": id}])


    # Setup timer to remove after duration
    var t := Timer.new()
    t.wait_time = duration
    t.one_shot = true
    t.timeout.connect(_on_expire.bind(t, id))
    add_child(t)
    t.start()

func _on_expire(t: Timer, id: int):
    if target_stats:
        target_stats.remove_modifier(modifiers)
    if target_em:
        target_em.emit_event("on_debuff_removed", [{"debuff": self, "holder": holder, "target": target, "id": id}])    
    t.queue_free()
