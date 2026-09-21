#hit_flash_manager
# Isolated damage-flash tween spawner, mirrors ParticleEffectManager/TextureBurstManager
# architecture: lives as a child of the owner (Character/Enemy), subscribes to
# `before_take_damage`, and tweens the owner's sprite modulate. No combat logic
# lives in the owner script.
extends Node2D

@onready var event_manager: EventManager = get_parent().get_node_or_null("EventManager")

@export var sprite_path: NodePath = "Node2D/Sprite2D"

func _ready():
    event_manager.subscribe("before_take_damage", Callable(self, "_flash"))

func _flash(_event):
    var sprite := get_parent().get_node_or_null(sprite_path) as Sprite2D
    if sprite == null:
        return
    var tween = create_tween()
    tween.tween_property(sprite, "modulate", Color(1, 4, 1), 0.1)
    tween.tween_property(sprite, "modulate", Color(4, 1, 1, 0), 0.1).from(Color(1, 1, 4))
    tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.0)