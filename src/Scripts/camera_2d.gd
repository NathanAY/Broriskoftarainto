extends Camera2D

@export var target: Node2D
@export var follow_speed: float = 3.0

@export var zoom_step: float = 0.07
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.0

## Screen shake, in pixels of `offset` at 100% on the options slider. The
## target's own `on_attack` gives the small kick, `after_take_damage` the big one.
@export var attack_shake: float = 2.0
@export var damage_shake: float = 9.0
## Pixels per second the shake fades by.
@export var shake_decay: float = 40.0

## Current shake amplitude in pixels. A new kick only raises it to the kick's
## size, never adds to it: an area weapon fires `on_attack` once per enemy hit,
## and stacking those would shake far harder than a single attack.
var shake_strength: float = 0.0


func _ready() -> void:
    if target == null:
        return
    var events := target.get_node_or_null("EventManager") as EventManager
    if events:
        events.subscribe("on_attack", _on_target_attack)
        events.subscribe("after_take_damage", _on_target_damaged)


func _physics_process(delta):
    if target:
        position = position.lerp(target.global_position, delta * follow_speed)


func _process(delta: float) -> void:
    shake_strength = move_toward(shake_strength, 0.0, shake_decay * delta)
    offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength


## Raises the shake to `pixels` scaled by the options slider. At 0% this is a
## no-op, so the camera never moves off its target.
func shake(pixels: float) -> void:
    shake_strength = maxf(shake_strength, pixels * GameSettings.screen_shake / 100.0)


func _on_target_attack(_event: Dictionary) -> void:
    shake(attack_shake)


func _on_target_damaged(event: Dictionary) -> void:
    var ctx: DamageContext = event["damage_context"]
    if ctx.final_amount > 0.0:
        shake(damage_shake)


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _change_zoom(-zoom_step)
        elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _change_zoom(zoom_step)

func _change_zoom(amount: float) -> void:
    var new_zoom = zoom + Vector2(amount, amount)
    new_zoom.x = clamp(new_zoom.x, min_zoom, max_zoom)
    new_zoom.y = clamp(new_zoom.y, min_zoom, max_zoom)
    zoom = new_zoom
