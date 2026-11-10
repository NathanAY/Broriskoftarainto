extends Node2D

## Dev-only fixture: the Gamepedia on its own, so a one-shot render can reach it
## (its real route is a menu button). Pass a tab index as the 4th `run_scene_shot`
## user arg is not supported; edit `TAB` to look at another tab.
const TAB := 0


func _ready() -> void:
	var gamepedia := Gamepedia.new()
	add_child(gamepedia)
	gamepedia.tabs.current_tab = TAB
