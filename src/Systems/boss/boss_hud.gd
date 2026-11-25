## The final boss's screen UI: a wide health bar across the top of the screen
## with a tick at every phase threshold, and the name card that plays when the
## boss arrives. It is a `CanvasLayer` child of the boss, so it appears with the
## boss and goes when the boss is freed. `BossBrain` builds it in `_ready`.
extends CanvasLayer
class_name BossHud

const BAR_COLOR := Color(0.95, 0.74, 0.2)
const BAR_ENRAGED := Color(0.9, 0.3, 0.25)
const BAR_BACK := Color(0.15, 0.16, 0.2, 0.85)
const TICK_COLOR := Color(1, 1, 1, 0.9)

var bar: BossHealthBar = null
var name_card: Control = null


## `title` / `subtitle` are the boss's name and epithet; `thresholds` the phase
## health fractions the bar marks.
func setup(boss: Enemy, title: String, subtitle: String, thresholds: Array, card_time: float) -> void:
    layer = 5
    bar = BossHealthBar.new()
    bar.title = title
    bar.thresholds = thresholds
    bar.anchor_left = 0.2
    bar.anchor_right = 0.8
    bar.offset_top = 16.0
    bar.offset_bottom = 58.0
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bar)
    var bus := boss.get_node_or_null("EventManager") as EventManager
    if bus != null:
        bus.subscribe("on_health_changed", Callable(bar, "_on_health_changed"))
    _show_card(title, subtitle, card_time)


func set_enraged(enraged: bool) -> void:
    if bar != null:
        bar.fill_color = BAR_ENRAGED if enraged else BAR_COLOR
        bar.queue_redraw()


func _show_card(title: String, subtitle: String, card_time: float) -> void:
    if card_time <= 0.0:
        return
    name_card = VBoxContainer.new()
    name_card.anchor_left = 0.0
    name_card.anchor_right = 1.0
    name_card.anchor_top = 0.22
    name_card.anchor_bottom = 0.22
    name_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    name_card.alignment = BoxContainer.ALIGNMENT_CENTER
    name_card.add_child(_label(title, 64, BAR_COLOR))
    name_card.add_child(_label(subtitle, 26, Color(0.85, 0.85, 0.85)))
    name_card.modulate.a = 0.0
    add_child(name_card)
    var tween := name_card.create_tween()
    tween.tween_property(name_card, "modulate:a", 1.0, card_time * 0.2)
    tween.tween_interval(card_time * 0.55)
    tween.tween_property(name_card, "modulate:a", 0.0, card_time * 0.25)
    tween.tween_callback(name_card.queue_free)


static func _label(text: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var settings := LabelSettings.new()
    settings.font_size = font_size
    settings.font_color = color
    settings.outline_size = maxi(4, int(font_size / 6.0))
    settings.outline_color = Color.BLACK
    label.label_settings = settings
    return label
