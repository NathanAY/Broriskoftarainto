extends Node2D
## A player stand-in standing on each portal, for checking the portal is drawn
## behind it. Like the real phase, the "player" comes *before* the portals in the
## tree, which is the order that used to paint the portal over it.
##
##     .\run_scene_shot.bat res://test/tools/portal_overlap_preview.tscn res://portal_overlap_shot.png 10

const STAGE_PORTAL: PackedScene = preload("res://src/Systems/StageChoicePortal.tscn")
const SHOP_PORTAL: PackedScene = preload("res://src/Systems/ShopPortal.tscn")
const BACKDROP := Color(0.78, 0.71, 0.58)


func _ready() -> void:
	var view := get_viewport_rect().size
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.size = view
	backdrop.z_index = -10
	add_child(backdrop)

	var y := view.y * 0.55
	var spots: Array[Vector2] = [
		Vector2(view.x * 0.25, y), Vector2(view.x * 0.75, y)]
	for spot in spots:
		var player := Polygon2D.new()
		player.polygon = PackedVector2Array([
			Vector2(-18, -18), Vector2(18, -18), Vector2(18, 18), Vector2(-18, 18)])
		player.color = Color(0.1, 0.2, 0.9)
		player.position = spot
		add_child(player)

	var stage: Node2D = STAGE_PORTAL.instantiate()
	stage.position = spots[0]
	add_child(stage)
	var shop: Node2D = SHOP_PORTAL.instantiate()
	shop.position = spots[1]
	add_child(shop)
