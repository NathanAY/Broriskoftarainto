# hit_flash_manager
# Isolated damage-flash tween spawner, mirrors ParticleEffectManager/TextureBurstManager
# architecture: lives as a child of the owner (Character/Enemy), subscribes to
# `before_take_damage`, and tweens the owner's sprite modulate to a color depending
# on the damage type/tags: poison=green, melee=red, explosion=yellow, ranged=white.
# No combat logic lives in the owner script.
extends Node2D

const FLASH_COLORS := {
    "poison": Color(0.2, 1.8, 0.4),
    "melee": Color(1.8, 0.2, 0.2),
    "explosion": Color(1.8, 1.6, 0.2),
    "ranged": Color(1.6, 1.6, 1.6),
}

const FLASH_IN_DURATION := 0.08
const FLASH_OUT_DURATION := 0.15

@onready var event_manager: EventManager = get_parent().get_node_or_null("EventManager")

@export var sprite_path: NodePath = "Node2D/Sprite2D"

var _tween: Tween = null

func _ready():
    event_manager.subscribe("before_take_damage", Callable(self, "_flash"))

func _flash(event: Dictionary):
    var sprite := get_parent().get_node_or_null(sprite_path) as Sprite2D
    if sprite == null:
        return
    if _tween:
        _tween.kill()
    var color := _color_for(event.get("damage_context") as DamageContext)
    _tween = create_tween()
    _tween.tween_property(sprite, "modulate", color, FLASH_IN_DURATION)
    _tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), FLASH_OUT_DURATION)

func _color_for(ctx: DamageContext) -> Color:
    if ctx == null:
        return FLASH_COLORS["ranged"]
    if "poison" in ctx.tags or ctx.damage_type == "poison":
        return FLASH_COLORS["poison"]
    if "melee" in ctx.tags or "contact" in ctx.tags or ctx.damage_type == "melee":
        return FLASH_COLORS["melee"]
    if "explosion" in ctx.tags or ctx.damage_type in ["fire", "explosion"]:
        return FLASH_COLORS["explosion"]
    return FLASH_COLORS["ranged"]