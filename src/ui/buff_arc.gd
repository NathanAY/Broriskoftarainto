extends Control
class_name BuffArc

## The duration arc drawn over a `BuffTile`: a ring from twelve o'clock,
## clockwise, swept by `fraction` of the buff's remaining time. Under
## `BuffEntry.EXPIRING_FRACTION` it turns red, so a buff about to lapse is
## visible without reading the number in the tooltip.
##
## This is a bare `Control` with a `_draw()` rather than a texture because the
## sweep changes every frame - a redraw is cheaper than re-uploading a canvas
## item. It draws nothing at all when `fraction <= 0` or is hidden, which is what
## a buff with no running timer gets.
##
## Only `BuffTile` owns one; the knobs are public because the tile is the thing
## that decides the size, not the node that paints inside it.

## How full the ring is, 0..1. 0 draws nothing.
var fraction: float = 0.0
var color: Color = ItemDisplayPanel.COLOR_HEADING
## Inset from the control's edge. The tile's 2px plate border sits under it.
var margin: float = 3.0
var width: float = 2.0

## Where the sweep starts: twelve o'clock, so a full ring closes where it opened.
const START_ANGLE := -PI / 2.0


func _draw() -> void:
    if fraction <= 0.0:
        return
    var radius := (minf(size.x, size.y) * 0.5) - margin
    if radius <= 0.0:
        return
    var center := size * 0.5
    draw_arc(center, radius, START_ANGLE, START_ANGLE + TAU * fraction, 48, color, width, true)
