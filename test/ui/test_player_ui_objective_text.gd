# GdUnit TestSuite for the HUD objective line in PlayerUI.
#
# The line tells the player what the current stage wants: survive the timer, kill
# what is left once it runs out, or kill the boss. These tests pin the wording and
# the switch points. Counts and wording are mechanics, so they are literals; the
# stage duration is passed in rather than read from the .tres.
class_name PlayerUiObjectiveTextTest
extends GdUnitTestSuite

const PLAYER_UI_SCRIPT := preload("res://src/ui/player_ui.gd")


func test_wave_shows_seconds_left_with_loop_and_dot() -> void:
	var text: String = PLAYER_UI_SCRIPT.objective_text(1, StageManager.STAGE_WAVE, 20.0, 0.0)
	assert_str(text).is_equal("Loop 1. Survive 20 seconds")


func test_wave_counts_down_as_time_elapses() -> void:
	var text: String = PLAYER_UI_SCRIPT.objective_text(1, StageManager.STAGE_WAVE, 20.0, 5.5)
	assert_str(text).is_equal("Loop 1. Survive 14 seconds")


func test_wave_past_timer_asks_to_kill_remaining_enemies() -> void:
	var text: String = PLAYER_UI_SCRIPT.objective_text(1, StageManager.STAGE_WAVE, 20.0, 25.0)
	assert_str(text).is_equal("Loop 1. Kill remaining enemies")


func test_wave_exactly_at_timer_end_asks_to_kill_remaining_enemies() -> void:
	var text: String = PLAYER_UI_SCRIPT.objective_text(2, StageManager.STAGE_WAVE, 20.0, 20.0)
	assert_str(text).is_equal("Loop 2. Kill remaining enemies")


func test_boss_stage_asks_to_kill_the_boss() -> void:
	var text: String = PLAYER_UI_SCRIPT.objective_text(1, StageManager.STAGE_BOSS, 20.0, 20.0)
	assert_str(text).is_equal("Loop 1. Kill the boss")


func test_shop_stage_after_boss_asks_to_explore_area() -> void:
	var text: String = PLAYER_UI_SCRIPT.objective_text(3, StageManager.STAGE_SHOP, 20.0, 0.0)
	assert_str(text).is_equal("Loop 3. Explore area")


func test_boss_stage_never_shows_a_negative_or_survive_value() -> void:
	var text: String = PLAYER_UI_SCRIPT.objective_text(1, StageManager.STAGE_BOSS, 20.0, 0.0)
	assert_bool(text.contains("Survive")).is_false()
	assert_bool(text.contains("-")).is_false()
