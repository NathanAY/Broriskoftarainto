# heal_pickup.gd
# Dropped by enemies (see spawner_modifier.gd). Walking over it heals the player.
extends Area2D

## Fraction of the character's max health restored on pickup.
@export var heal_fraction: float = 0.1
## Flat health restored on top of the fraction.
@export var heal_flat: float = 2.0

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    # Cheap glow: one additive sprite whose alpha pulses on a looping tween.
    var glow := get_node_or_null("Glow") as Sprite2D
    if glow:
        var pulse := create_tween().set_loops()
        pulse.tween_property(glow, "modulate:a", 0.35, 0.9).set_trans(Tween.TRANS_SINE)
        pulse.tween_property(glow, "modulate:a", 0.7, 0.9).set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node) -> void:
    if not body is Character:
        return
    var health: Health = body.get_node_or_null("Health")
    if health == null:
        return
    health.heal(health.max_health * heal_fraction + heal_flat)
    queue_free()
