#texture_burst_manager
# Isolated death-burst spawner, mirrors ParticleEffectManager architecture:
# lives as a child of the owner (e.g. Enemy.tscn), subscribes to `on_death`,
# and spawns a reusable TextureBurst. No combat logic lives in the owner script.
extends Node2D

@onready var event_manager: EventManager = get_parent().get_node_or_null("EventManager")

@export var sprite_path: NodePath = "Node2D/Sprite2D"
@export var burst_scene: PackedScene = preload("res://src/Scenes/effects/TextureBurst.tscn")

func _ready():
    event_manager.subscribe("on_death", Callable(self, "_emit_burst"))

func _emit_burst(event: Dictionary):
    var holder: Node = get_parent()
    if holder == null:
        return
    var sprite := holder.get_node_or_null(sprite_path) as Sprite2D
    if sprite == null or sprite.texture == null:
        return
    var target_parent: Node = holder.get_parent()
    if target_parent == null:
        return
    var direction := Vector2.RIGHT
    var strength := 1.0
    var ctx: DamageContext = event.get("damage_context")
    if ctx != null:
        if ctx.source is Node2D and is_instance_valid(ctx.source) and holder is Node2D:
            var to_self: Vector2 = (holder as Node2D).global_position - (ctx.source as Node2D).global_position
            if to_self.length_squared() > 0.0001:
                direction = to_self.normalized()
        # Scale burst push by killing blow size (mirrors WW power 0.8-2.2 clamp).
        var percent: float = float(ctx.target_take_persent_damage)
        if percent > 0.0:
            strength = clampf(0.8 + percent * 1.5, 0.8, 2.2)
    var burst = burst_scene.instantiate()
    target_parent.add_child(burst)
    if burst is Node2D and sprite is Node2D:
        (burst as Node2D).global_position = (sprite as Node2D).global_position
    burst.configure(sprite, direction, strength)
