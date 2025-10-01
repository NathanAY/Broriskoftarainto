# This node lives on the target, not the enemy
class_name Debuff
extends Node

var holder: Node
var target: Node
var target_stats: Stats
var target_em: EventManager
var modifiers: Dictionary
var duration: float

func setup(holder: Node, target: Node, mod: Dictionary, duration: float):
    self.holder = holder
    self.target = target
    self.target_stats = target.get_node_or_null("Stats")
    self.target_em = target.get_node_or_null("EventManager")
    self.duration = duration

    # Apply unique modifier copy
    modifiers = {}
    for k in mod.keys():
        modifiers[k] = mod[k].duplicate(true)
    if target_stats:
        target_stats.add_modifier(modifiers)

    # Timer lives inside this instance
    var t := Timer.new()
    t.wait_time = duration
    t.one_shot = true
    t.timeout.connect(_on_expire.bind(t))
    target.add_child(t)
    t.start()

func _on_expire(t: Timer):
    if target_stats:
        target_stats.remove_modifier(modifiers)
    if target_em:
        target_em.emit_event("on_debuff_removed", [{
            "debuff": self,
            "holder": holder,
            "target": target
        }])
    t.queue_free()
    queue_free()
    
