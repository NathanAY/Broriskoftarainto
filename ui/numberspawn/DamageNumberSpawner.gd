extends Node

@export var event_manager: EventManager
@export var damage_number_scene: PackedScene   # assign DamageNumber.tscn in inspector
var spawn_offset: float = 20.0         # max random horizontal/vertical jitter

func _ready() -> void:
    event_manager.subscribe("after_deal_damage", Callable(self, "_show_damage"))

func _show_damage(event: Dictionary) -> void:
    var ctx: DamageContext = event["damage_context"]
    var damage = ctx.final_amount + ctx.energy_shield_absorbed
    var body = ctx.target
    var dmg_num = damage_number_scene.instantiate()
    get_tree().current_scene.add_child(dmg_num)  # add to world/layer
    var random_offset = Vector2(
        randf_range(-spawn_offset, spawn_offset),
        randf_range(-spawn_offset, spawn_offset) - 10 # bias upward
    )
    if (ctx.tags.has("poison")):
        dmg_num.color = Color(0, 1, 0)
    if (ctx.tags.has("explosion")):
        dmg_num.color = Color.YELLOW
    dmg_num.global_position = body.global_position + random_offset
    dmg_num.show_damage(damage)
