extends Node

## Renders the weapons & items panel pointed at an enemy, so its layout and title
## can be checked with `run_scene_shot.bat` - the real route needs a live pause
## screen and a live enemy, which a one-shot render cannot reach.

func _ready() -> void:
	var enemy: Enemy = load("res://src/Systems/Enemy.tscn").instantiate()
	add_child(enemy)
	var panel: CanvasLayer = load("res://src/Scenes/menu/ConfigureMenu.tscn").instantiate()
	# Target before tree entry, the order the pause menu uses.
	panel.target_entity = enemy
	add_child(panel)
	panel._on_add_weapon("res://src/Resources/weapons/Pistol.tres", null, null)
	panel._add_item_to_holder(
		ItemBuilder.make_stat_item("Debug_damage_1.0", "damage 1.0 (debug)", {"damage": {"flat": 1.0}}), null
	)
	panel._refresh_equipped_list()
	panel._refresh_equipped_items()
	panel.visible = true