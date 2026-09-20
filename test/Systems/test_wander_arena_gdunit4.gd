class_name WanderArenaGdUnit4Test
extends GdUnitTestSuite


func _make_behaviour() -> Node:
	var behaviour: Node = auto_free(load("res://src/Systems/movement/bahaviour/WanderAroundMovementBehaviour.tscn").instantiate())
	add_child(behaviour)
	return behaviour


func _make_creature_at(pos: Vector2) -> CharacterBody2D:
	var creature := CharacterBody2D.new()
	auto_free(creature)
	add_child(creature)
	creature.global_position = pos
	return creature


func test_edge_margin_default_is_50() -> void:
	var behaviour := _make_behaviour()
	assert_float(behaviour.get("edge_margin")).is_equal(50.0)


func test_wander_goals_stay_50px_from_edge() -> void:
	var arena: Arena = auto_free(load("res://src/Systems/Arena.tscn").instantiate())
	add_child(arena)
	var behaviour := _make_behaviour()
	# Creature near the corner so random offsets often push outside.
	var creature := _make_creature_at(Vector2(950, 700))
	for i in range(30):
		behaviour.set("current_goal", Vector2.ZERO)
		behaviour.call("_pick_new_goal", creature)
		var goal: Vector2 = behaviour.get("current_goal")
		assert_bool(arena.is_inside(goal, 49.0)).is_true()


func test_wander_goals_stay_inside_when_centered() -> void:
	var arena: Arena = auto_free(load("res://src/Systems/Arena.tscn").instantiate())
	add_child(arena)
	var behaviour := _make_behaviour()
	var creature := _make_creature_at(Vector2.ZERO)
	for i in range(20):
		behaviour.set("current_goal", Vector2.ZERO)
		behaviour.call("_pick_new_goal", creature)
		var goal: Vector2 = behaviour.get("current_goal")
		assert_bool(arena.is_inside(goal, 49.0)).is_true()


func test_clamp_goal_outside_pulls_inside_with_margin() -> void:
	var arena: Arena = auto_free(load("res://src/Systems/Arena.tscn").instantiate())
	add_child(arena)
	var behaviour := _make_behaviour()
	var clamped: Vector2 = behaviour.call("clamp_goal_to_arena", Vector2(99999, -99999))
	assert_bool(arena.is_inside(clamped, 49.0)).is_true()


func test_wander_unclamped_without_arena() -> void:
	var behaviour := _make_behaviour()
	assert_object(behaviour.get("arena")).is_null()
	var pos := Vector2(99999, -99999)
	var result: Vector2 = behaviour.call("clamp_goal_to_arena", pos)
	assert_that(result).is_equal(pos)
