extends Camera2D

@export var target: Node2D
@export var follow_speed: float = 3.0

@export var zoom_step: float = 0.07
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.0

func _physics_process(delta):
    if target:
        position = position.lerp(target.global_position, delta * follow_speed)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _change_zoom(-zoom_step)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _change_zoom(zoom_step)

func _change_zoom(amount: float) -> void:
    var new_zoom = zoom + Vector2(amount, amount)
    new_zoom.x = clamp(new_zoom.x, min_zoom, max_zoom)
    new_zoom.y = clamp(new_zoom.y, min_zoom, max_zoom)
    zoom = new_zoom
