## A circle drawn on the ground: an outline at `radius` and a disc that fills
## it as `progress` goes from 0 to 1. The Safe Drop's landing shadow (the disc
## filling is the countdown) and the phase-change shockwave ring.
extends Node2D
class_name GroundMarker

@export var radius: float = 90.0:
    set(value):
        radius = value
        queue_redraw()
## 0..1: how much of the circle the inner disc fills.
@export_range(0.0, 1.0) var progress: float = 0.0:
    set(value):
        progress = value
        queue_redraw()
@export var color: Color = Color(0.0, 0.0, 0.0, 0.35)
@export var outline_color: Color = Color(0.9, 0.2, 0.1, 0.8)
@export var outline_width: float = 4.0


func _ready() -> void:
    z_index = -1


func _draw() -> void:
    if progress > 0.0:
        draw_circle(Vector2.ZERO, radius * progress, color)
    if outline_width > 0.0:
        draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, outline_color, outline_width, true)
