## The boss bar itself: the boss's name over a long bar, with a white tick at
## each phase threshold so the player sees the next phase coming. Drawn rather
## than built from nodes, so the ticks always sit at their exact fraction.
extends Control
class_name BossHealthBar

var title: String = ""
var thresholds: Array = []
## 0..1, the boss's current health over its max.
var fraction: float = 1.0
var fill_color: Color = BossHud.BAR_COLOR

const BAR_HEIGHT := 16.0


func _on_health_changed(event: Dictionary) -> void:
    var max_health := float(event.get("max_health", 1.0))
    fraction = clampf(float(event.get("current_health", max_health)) / maxf(max_health, 0.001), 0.0, 1.0)
    queue_redraw()


func _draw() -> void:
    var font := get_theme_default_font()
    var font_size := 20
    draw_string_outline(font, Vector2(0, font_size), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, 6, Color.BLACK)
    draw_string(font, Vector2(0, font_size), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color.WHITE)
    var bar := Rect2(0, size.y - BAR_HEIGHT, size.x, BAR_HEIGHT)
    draw_rect(bar.grow(2.0), Color.BLACK)
    draw_rect(bar, BossHud.BAR_BACK)
    draw_rect(Rect2(bar.position, Vector2(bar.size.x * fraction, bar.size.y)), fill_color)
    for t in thresholds:
        var x := bar.size.x * float(t)
        draw_line(Vector2(x, bar.position.y - 3), Vector2(x, bar.end.y + 3), BossHud.TICK_COLOR, 3.0)
