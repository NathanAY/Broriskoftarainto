# GdUnit TestSuite for the enemy art fit. The fit runs in the editor and again in
# `_ready`, so it must be idempotent, and changing `art_width` must re-fit the art
# straight away so the editor view matches the game.
class_name EnemyFitTest
extends GdUnitTestSuite

const BLINK_SCENE := "res://src/Systems/enemies/EnemyBlink.tscn"


func test_refitting_does_not_compound_the_scale() -> void:
	var enemy: Enemy = load(BLINK_SCENE).instantiate()
	add_child(enemy)
	await get_tree().process_frame

	var fitted := enemy.visual.scale
	enemy._fit_sprite()
	enemy._fit_sprite()
	assert_that(enemy.visual.scale).is_equal_approx(fitted, Vector2.ONE * 0.0001)

	enemy.free()


func test_changing_art_width_refits_the_drawn_size() -> void:
	var enemy: Enemy = load(BLINK_SCENE).instantiate()
	add_child(enemy)
	await get_tree().process_frame

	enemy.art_width = 60.0
	assert_float(enemy.drawn_width()).is_equal_approx(60.0, 0.5)

	enemy.free()
