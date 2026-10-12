extends Node

## Renders the sandbox panel on its own, so its layout can be checked with
## `run_scene_shot.bat` - which cannot open a pause menu mid-run the way the real
## panel is reached. No character: the panel only needs one to spawn into, and a
## stand-in would not render any differently.

func _ready() -> void:
	var menu := SandboxMenu.new()
	menu.name = "SandboxMenu"
	menu.setup(get_node("Enemies"), null)
	add_child(menu)
	menu.open()