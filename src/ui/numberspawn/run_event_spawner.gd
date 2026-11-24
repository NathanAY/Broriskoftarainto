extends Node
class_name RunEventSpawner
## Floating text over the character for every `on_run_event` ("+12 Coins",
## "+0.5 Health"), so an effect that pays out is seen when it happens. Several
## events in one frame (a payday's interest and dividend) stack upward instead
## of landing on top of each other. See `docs/systems/run_history.md`.

const COINS_COLOR := Color.GOLD
const GAIN_COLOR := Color(0.5, 1.0, 0.6)
const LOSS_COLOR := Color(1.0, 0.35, 0.35)

@export var event_manager: EventManager
@export var floating_text_scene: PackedScene
## Seconds a message stays up; longer than a damage number so it can be read.
@export var lifetime: float = 1.6
## Pixels above the character the first message starts.
@export var height: float = 60.0
## Pixels between messages spawned in the same frame.
@export var line_spacing: float = 22.0

var _frame: int = -1
var _in_frame: int = 0


func _ready() -> void:
    event_manager.subscribe("on_run_event", _on_run_event)


static func color_for(what: String, amount: float) -> Color:
    if amount < 0.0:
        return LOSS_COLOR
    return COINS_COLOR if what == "coins" else GAIN_COLOR


func _on_run_event(event: Dictionary) -> void:
    var body := event_manager.get_parent() as Node2D
    if body == null or not body.is_inside_tree():
        return
    var frame := Engine.get_process_frames()
    _in_frame = _in_frame + 1 if frame == _frame else 0
    _frame = frame

    var text: FloatingNumber = floating_text_scene.instantiate()
    text.color = color_for(event["what"], float(event["amount"]))
    text.lifetime = lifetime
    text.start_scale = 1.2
    var scene := get_tree().current_scene
    (scene if scene else body.get_parent()).add_child(text)
    text.global_position = body.global_position + Vector2(-20.0, -height - line_spacing * _in_frame)
    text.show_text("%s (%s)" % [RunHistory.amount_text(event["what"], float(event["amount"])), event["source"]])
