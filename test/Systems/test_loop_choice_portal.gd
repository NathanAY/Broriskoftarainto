class_name LoopChoicePortalTest
extends GdUnitTestSuite

## Pins two things about the end-of-run portals that players can see:
##  - the portal is drawn behind the player, so standing on it never hides the
##    character under the portal sprite,
##  - Tab (`ui_focus_next`, routed to `cancel_action`) cannot remove the portal,
##    and the menu does not offer "Leave", because the answer is forced.

const LOOP_PORTAL: PackedScene = preload("res://src/Systems/LoopChoicePortal.tscn")


func _portal() -> LoopChoicePortal:
	var portal := LOOP_PORTAL.instantiate() as LoopChoicePortal
	add_child(portal)
	return portal


func _tab_event() -> InputEventAction:
	var tab := InputEventAction.new()
	tab.action = "ui_focus_next"
	tab.pressed = true
	return tab


## The stage's `Nodes` container is added after `Character` in the scene tree, so
## without an explicit z_index the portal sprite paints over the player. Actors
## sit at z 0, so the portal must sit below zero.
func test_portal_is_drawn_behind_the_player() -> void:
	var portal := _portal()
	assert_int(portal.z_index).is_less(0)


## The shop portal shares the sprite and the problem; the fix lives in each scene.
func test_shop_portal_is_drawn_behind_the_player() -> void:
	var portal := (load("res://src/Systems/ShopPortal.tscn") as PackedScene).instantiate()
	add_child(portal)
	assert_int((portal as Node2D).z_index).is_less(0)


func test_tab_does_not_destroy_the_loop_portal() -> void:
	var portal := _portal()
	var manager := InteractionManager.new()
	add_child(manager)
	manager.current = portal

	manager._unhandled_input(_tab_event())

	assert_bool(portal.is_queued_for_deletion()).is_false()


func test_menu_does_not_offer_leave_on_the_loop_portal() -> void:
	var portal := _portal()
	portal.show_menu()

	var leave_button: Button = portal.interaction_menu.get_node("Button2")
	assert_bool(leave_button.visible).is_false()
