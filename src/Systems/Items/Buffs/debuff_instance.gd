# This node lives on the target, not the enemy
class_name Debuff
extends Node

var holder: Node
var target: Node
var target_stats: Stats
var target_em: EventManager
var modifiers: Dictionary
var duration: float
## The `DebuffSource` that spawned this instance. Debuffs do not stack at the
## source - every trigger makes a separate node - so this is what the UI groups
## on: two instances from one source are one tile with a summed total.
var source: Node = null
## This instance's own expiry timer. Kept as a reference (and parented to `self`,
## not to the target) so a caller can read the remaining time without scanning
## the tree.
var timer: Timer = null
## Passed through from the `DebuffSource`, empty falls back to the humanized
## primary stat in the UI.
var display_name: String = ""
var tooltip_text: String = ""

func setup(p_holder: Node, p_target: Node, mod: Dictionary, p_duration: float,
        p_source: Node = null, p_display_name: String = "", p_tooltip_text: String = ""):
    self.holder = p_holder
    self.target = p_target
    self.target_stats = p_target.get_node_or_null("Stats")
    self.target_em = p_target.get_node_or_null("EventManager")
    self.duration = p_duration
    self.source = p_source
    self.display_name = p_display_name
    self.tooltip_text = p_tooltip_text

    # Apply unique modifier copy
    modifiers = {}
    for k in mod.keys():
        modifiers[k] = mod[k].duplicate(true)
    if target_stats:
        target_stats.add_modifier(modifiers)

    # Timer lives inside this instance. Parented to `self` and not to `target`:
    # a debuff on the player is one tile, and a timer parked on the target made
    # "how long is this debuff" unanswerable without a tree-wide search.
    # Started from `_ready()`, not here: `DebuffSource._on_trigger()` calls
    # setup() and only then adds the node, and a Timer started off-tree does not
    # run at all.
    var t := Timer.new()
    t.wait_time = duration
    t.one_shot = true
    t.timeout.connect(_on_expire.bind(t))
    add_child(t)
    timer = t


func _ready() -> void:
    if timer != null:
        timer.start()

## Seconds left before this instance expires, or 0.0 once its timer is gone.
func remaining_time() -> float:
    if timer == null or not is_instance_valid(timer):
        return 0.0
    return timer.time_left

func _on_expire(t: Timer):
    if target_stats:
        target_stats.remove_modifier(modifiers)
    if target_em:
        target_em.emit_event("on_debuff_removed", {
            "debuff": self,
            "holder": holder,
            "target": target
        })
    t.queue_free()
    queue_free()
