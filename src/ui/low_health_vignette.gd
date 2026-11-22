extends TextureRect
class_name LowHealthVignette

## A dark shadow around the screen edges that deepens as the character's health
## drops: invisible at full health, `max_alpha` at zero. Driven by the
## character's `on_health_changed`, so damage, heals and max-health changes all
## move it.
##
## The shadow is a radial `GradientTexture2D` stretched over the whole screen
## (so it follows the window's aspect), built here rather than in a `.tres`.

@export var character: Character
## Opacity at zero health. Below 1 so the player can still see what killed them.
@export var max_alpha: float = 0.85
## How far from the centre (0 = centre, 1 = mid-edge) the shadow starts.
@export var clear_radius: float = 0.45
@export var shadow_color: Color = Color(0.0, 0.0, 0.0)


func _ready() -> void:
    # Anchors *and* offsets: anchors alone leave the rect at size 0.
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    stretch_mode = TextureRect.STRETCH_SCALE
    texture = _make_texture()
    modulate.a = 0.0
    if character == null:
        return
    var health := character.get_node_or_null("Health") as Health
    if health:
        set_health(health.current_health, health.max_health)
    if character.event_manager:
        character.event_manager.subscribe("on_health_changed", _on_health_changed)


## Shadow opacity for a health reading: 0 at full, `max_alpha` at none.
func set_health(current: float, maximum: float) -> void:
    var missing := 1.0 - clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
    modulate.a = missing * max_alpha


func _on_health_changed(event: Dictionary) -> void:
    set_health(event["current_health"], event["max_health"])


func _make_texture() -> GradientTexture2D:
    var gradient := Gradient.new()
    var clear := Color(shadow_color, 0.0)
    gradient.offsets = PackedFloat32Array([0.0, clear_radius, 1.0])
    gradient.colors = PackedColorArray([clear, clear, shadow_color])
    var tex := GradientTexture2D.new()
    tex.gradient = gradient
    tex.fill = GradientTexture2D.FILL_RADIAL
    tex.fill_from = Vector2(0.5, 0.5)
    tex.fill_to = Vector2(1.0, 0.5)
    tex.width = 256
    tex.height = 256
    return tex
