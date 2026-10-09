# Enemy has this
class_name DebuffSource
extends Node

@export var trigger_event: String = "after_deal_damage"
@export var duration: float = 3.0
@export var modifiers: Dictionary = { "armor": {"flat": -10, "percent": -0.01} }
## Optional name carried onto every `Debuff` this source spawns. Empty falls
## back to the humanized primary stat in the UI.
@export var display_name: String = ""
## Optional prose carried onto every `Debuff` this source spawns.
@export var tooltip_text: String = ""

var holder: Node
var holder_em: EventManager

func _ready():
    holder = get_parent().hold_owner
    if not holder: return
    holder_em = holder.get_node_or_null("EventManager")
    if holder_em:
        holder_em.subscribe(trigger_event, Callable(self, "_on_trigger"))

func _on_trigger(event: Dictionary):
    var ctx: DamageContext = event["damage_context"]
    var target = ctx.target
    var target_em = target.get_node_or_null("EventManager")
    var target_stats = target.get_node_or_null("Stats")
    if not target_stats: return

    # Spawn an instance on target
    var debuff_instance := Debuff.new()
    # `self` goes in as the source: debuffs do not stack at the source, so this
    # back-reference is the only thing that lets the UI group two instances of
    # the same curse into one tile.
    debuff_instance.setup(holder, target, modifiers, duration, self, display_name, tooltip_text)
    target.add_child(debuff_instance)

    if target_em:
        target_em.emit_event("on_debuff_added", {
            "debuff": debuff_instance,
            "holder": holder,
            "target": target
        })
