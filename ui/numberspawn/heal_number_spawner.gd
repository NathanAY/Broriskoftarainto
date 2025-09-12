extends Node

@export var event_manager: Node
@export var damage_number_scene: PackedScene   # assign DamageNumber.tscn in inspector
var spawn_offset: float = 10.0         # max random horizontal/vertical jitter

func _ready() -> void:
    event_manager.subscribe("on_heal", Callable(self, "_on_heal"))

func _on_heal(event) -> void:
    var dmg_num = damage_number_scene.instantiate()
    dmg_num.color = Color(0, 1, 0)
    get_tree().current_scene.add_child(dmg_num)  # add to world/layer
    var random_offset = Vector2(
        randf_range(-spawn_offset, spawn_offset),
        randf_range(-spawn_offset, spawn_offset) - 10 # bias upward
    )
    dmg_num.global_position = event["self"].global_position + random_offset
    dmg_num.show_damage(event.amount)
