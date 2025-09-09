extends Node

@export var event_manager: Node
@export var damage_number_scene: PackedScene   # assign DamageNumber.tscn in inspector
var spawn_offset: float = 10.0         # max random horizontal/vertical jitter

func _ready() -> void:
    event_manager.subscribe("projectile_hit", Callable(self, "_on_projectile_hit"))

func _on_projectile_hit(projectile, body) -> void:
    var dmg_num = damage_number_scene.instantiate()
    get_tree().current_scene.add_child(dmg_num)  # add to world/layer
    var random_offset = Vector2(
        randf_range(-spawn_offset, spawn_offset),
        randf_range(-spawn_offset, spawn_offset) - 10 # bias upward
    )
    dmg_num.global_position = body.global_position + random_offset
    dmg_num.show_damage(projectile.damage)
