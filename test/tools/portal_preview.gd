extends Node2D
## The three portal variants side by side, for judging the vortex in one shot.
##
##     .\run_scene_shot.bat res://test/tools/portal_preview.tscn res://portal_shot.png 30
##
## The extra frames matter: the vortex animates, and the shot tool's own settle
## lands on its first frame.

const STAGE_PORTAL: PackedScene = preload("res://src/Systems/StageChoicePortal.tscn")
const SHOP_PORTAL: PackedScene = preload("res://src/Systems/ShopPortal.tscn")

## A dusty arena-floor tan, so the shot is judged against the surface the portals
## actually stand on rather than a black canvas.
const BACKDROP := Color(0.78, 0.71, 0.58)


func _ready() -> void:
	var view := get_viewport_rect().size
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.size = view
	# Portals sit at z -1 so the player draws over them; the floor goes under that.
	backdrop.z_index = -10
	add_child(backdrop)

	var y := view.y * 0.55
	_add_stage_portal(StageChoicePortal.Choice.FINAL_BOSS, "Final boss",
		Color(1.0, 0.55, 0.55), Vector2(view.x * 0.25, y))
	_add_stage_portal(StageChoicePortal.Choice.EXTRA_STAGE, "One more stage",
		Color(0.55, 0.85, 1.0), Vector2(view.x * 0.5, y))

	var shop: ShopPortal = SHOP_PORTAL.instantiate()
	shop.global_position = Vector2(view.x * 0.75, y)
	add_child(shop)


func _add_stage_portal(choice: StageChoicePortal.Choice, label_text: String,
		tint: Color, at: Vector2) -> void:
	var portal: StageChoicePortal = STAGE_PORTAL.instantiate()
	portal.choice = choice
	portal.label_text = label_text
	portal.tint = tint
	portal.global_position = at
	add_child(portal)
