class_name PortalEntryTest
extends GdUnitTestSuite

## Pins the portal entry animation (`src/Systems/portal.gd`) and the effects it
## drives:
##  - a portal acts only once its entry animation has played, and only once,
##  - the player is pulled into the portal, then restored and given control back,
##  - the shop portal draws every pickup into itself, and the shop still gets
##    every one of them,
##  - the aura is sized from the ring sprite (rule 1 of `docs/systems/effects.md`).

const SHOP_PORTAL := "res://src/Systems/ShopPortal.tscn"
const STAGE_PORTAL := "res://src/Systems/StageChoicePortal.tscn"
const PICKUP := "res://src/Systems/Items/ItemPickup.tscn"
const HEAL_PICKUP := "res://src/Systems/Items/HealPickup.tscn"

var _root: Node2D
var _saved_scene: Node


## The portal reaches the world through `get_tree().current_scene`, and
## `SceneTree` only accepts a `current_scene` parented to the root.
func before_test() -> void:
	_saved_scene = get_tree().current_scene
	_root = Node2D.new()
	_root.name = "PortalEntryRoot"
	get_tree().root.add_child(_root)
	get_tree().current_scene = _root


func after_test() -> void:
	get_tree().paused = false  # the shop pauses; a leaked pause freezes later suites
	get_tree().current_scene = _saved_scene
	_root.free()
	collect_orphan_node_details()


func _add_character(at: Vector2) -> Character:
	var character: Character = load("res://src/Systems/Character.tscn").instantiate()
	character.name = "Character"
	character.position = at
	_root.add_child(character)
	return character


func _add_portal(path: String, at: Vector2) -> Portal:
	var portal := (load(path) as PackedScene).instantiate() as Portal
	portal.position = at
	_root.add_child(portal)
	return portal


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func test_stage_portal_reports_only_after_the_entry_animation() -> void:
	var portal := _add_portal(STAGE_PORTAL, Vector2.ZERO)
	var reports: Array = []
	portal.chosen.connect(func(choice): reports.append(choice))

	portal.default_action()
	assert_int(reports.size()).override_failure_message(
		"the answer must wait for the animation").is_equal(0)

	await _wait(Portal.ENTRY_DURATION + 0.1)
	assert_array(reports).is_equal([portal.choice])


## Mashing Enter mid-animation must not answer the question twice.
func test_second_enter_during_the_animation_is_ignored() -> void:
	var portal := _add_portal(STAGE_PORTAL, Vector2.ZERO)
	var reports: Array = []
	portal.chosen.connect(func(choice): reports.append(choice))

	portal.default_action()
	await _wait(Portal.ENTRY_DURATION * 0.5)
	portal.default_action()
	await _wait(Portal.ENTRY_DURATION + 0.1)

	assert_int(reports.size()).is_equal(1)


func test_entry_pulls_the_player_in_and_pops_them_back_out() -> void:
	var portal := _add_portal(STAGE_PORTAL, Vector2(300, 200))
	var character := _add_character(Vector2(380, 260))
	var movement := character.get_node("Movement")
	var start_scale := character.scale

	var portal_position := portal.global_position
	# Late in the sink: the ease swells the player first (anticipation), so the
	# scale only drops below the start in the second half.
	var watch := func():
		await _wait(Portal.PULL_DURATION + Portal.SINK_DURATION * 0.8)
		assert_int(movement.process_mode).override_failure_message(
			"the player must not walk out mid-animation").is_equal(Node.PROCESS_MODE_DISABLED)
		assert_vector(character.global_position).is_equal_approx(portal_position, Vector2.ONE)
		assert_float(character.scale.x).is_less(start_scale.x)
	watch.call()
	# Returns as the pop-out starts; wait on it rather than racing a timer.
	await portal.default_action()
	await _wait(Portal.POP_DURATION + 0.2)
	assert_vector(character.scale).is_equal_approx(start_scale, Vector2(0.001, 0.001))
	assert_float(character.modulate.a).is_equal_approx(1.0, 0.001)
	assert_int(movement.process_mode).is_equal(Node.PROCESS_MODE_INHERIT)


func test_shop_portal_draws_pickups_in_and_hands_them_to_the_shop() -> void:
	var manager := InteractionManager.new()
	manager.name = "InteractionManager"
	_root.add_child(manager)
	var ui := Node.new()
	ui.name = "UI"
	_root.add_child(ui)
	var shop: ShopMenu = load("res://src/Scenes/menu/ShopMenu.tscn").instantiate()
	shop.name = "ShopMenu"
	ui.add_child(shop)
	var factory: ItemFactory = load("res://src/Systems/Items/ItemFactory.tscn").instantiate()
	_root.add_child(factory)
	shop.item_factory = factory
	GlobalGameState.current_character = _add_character(Vector2(40, 0))

	var nodes := Node.new()
	nodes.name = "Nodes"
	_root.add_child(nodes)
	var pickups := Node.new()
	pickups.name = "pickups"
	nodes.add_child(pickups)
	var spots := [Vector2(500, 0), Vector2(-400, 300)]
	for spot in spots:
		var pickup: Node2D = load(PICKUP).instantiate()
		pickup.item = factory.get_item_by_type("stat")
		pickup.position = spot
		pickups.add_child(pickup)
	# Heal drops share `Nodes/pickups` but have no `item`; they must neither
	# crash the harvest nor travel to the shop.
	var heal: Node2D = load(HEAL_PICKUP).instantiate()
	heal.position = Vector2(0, 600)
	pickups.add_child(heal)
	var portal := _add_portal(SHOP_PORTAL, Vector2.ZERO)
	await get_tree().process_frame  # interactables register deferred
	assert_int(manager.interactables.size()).is_equal(spots.size() + 1)

	portal.default_action()
	assert_array(manager.interactables).override_failure_message(
		"nothing flying into the portal can still be picked up").is_empty()

	await _wait(Portal.ENTRY_DURATION * 0.75)
	for i in spots.size():
		var pickup := pickups.get_child(i) as Node2D
		assert_float(pickup.global_position.distance_to(portal.global_position)) \
			.is_less(spots[i].length())
	assert_vector(heal.position).is_equal(Vector2(0, 600))

	await _wait(Portal.ENTRY_DURATION * 0.25 + 0.1)
	assert_bool(shop.visible).is_true()
	assert_int(shop.phase).is_equal(1)
	assert_int(shop._active_item_count()).is_equal(spots.size())


## Rule 1: the aura's ring comes from the sprite it decorates, so resizing the
## portal art cannot leave the motes and rune rings at the old size.
func test_aura_is_sized_from_the_ring_sprite() -> void:
	for path in [SHOP_PORTAL, STAGE_PORTAL]:
		var portal := _add_portal(path, Vector2.ZERO)
		var sprite := portal.get_node("Sprite2D") as Sprite2D
		assert_object(portal.aura).is_not_null()
		assert_float(portal.aura.radius).is_equal_approx(
			sprite.texture.get_width() * sprite.scale.x * 0.5, 0.01)
