extends Node2D
## Dev-only: the arena with the theme named by the ARENA_THEME environment variable (an index into `arena.themes`), for a one-shot render.
func _ready() -> void:
	var arena := load("res://src/Systems/Arena.tscn").instantiate() as Arena
	add_child(arena)
	var themes: Array = GameConfig.section("arena").get("themes", [])
	var index := int(OS.get_environment("ARENA_THEME"))
	arena.apply_theme(themes[index], index)
