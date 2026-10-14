# GdUnit TestSuite for which art `Stats.get_stat_icon()` picks.
#
# `get_stat_icon()` is the single funnel every stat row, item card and buff tile
# draws through, and it used to know about one folder. The stats that only exist
# because a modifier publishes into them - the two regen rates - therefore showed
# `_default.png`. Their art now lives in `src/Assets/modifiers/`, named after the
# stat key, and the lookup falls through to that folder. These tests pin the
# precedence (stats folder still wins) and the fallback, so moving an icon between
# folders is a deliberate act rather than an accident of which file happens to
# exist.
class_name StatIconLookupTest
extends GdUnitTestSuite

const STATS_ICON := "res://src/Assets/stats/damage.png"
const STATS_DEFAULT := "res://src/Assets/stats/_default.png"

## The two regen stats are the reason for the second folder: neither has art in
## `src/Assets/stats/`, and both are what a regen modifier publishes into. Each
## resolves to its OWN file - flat regen and percent regen are deliberately
## different drawings, so a test that compared both against one of them would be
## asserting that the percent art had been overwritten.
const REGEN_STATS: Array[String] = ["flat_regen_per_second", "percent_regen_per_second"]


func _modifier_icon_path(stat_name: String) -> String:
	return "res://src/Assets/modifiers/%s.png" % stat_name


func test_stats_folder_wins_over_modifiers_folder() -> void:
	# `damage` exists in the stats folder only, so precedence is unobservable here
	# - the point is that adding the fallback did not move the existing icons out.
	assert_object(Stats.get_stat_icon("damage")).is_same(
		_resource(STATS_ICON))


func test_regen_stat_resolves_to_modifier_folder_art() -> void:
	for stat_name in REGEN_STATS:
		assert_bool(ResourceLoader.exists("res://src/Assets/stats/%s.png" % stat_name)).override_failure_message(
			"Stops being a fallback case the moment %s gets its own stats-folder art" % stat_name).is_false()
		assert_object(Stats.get_stat_icon(stat_name)).is_same(
			_resource(_modifier_icon_path(stat_name)))


func test_regen_art_is_not_the_default_placeholder() -> void:
	# The failure the report was about: the row rendered as the blank plate.
	assert_object(Stats.get_stat_icon("flat_regen_per_second")).is_not_same(
		_resource(STATS_DEFAULT))


func test_unknown_stat_still_falls_back_to_default() -> void:
	assert_object(Stats.get_stat_icon("no_such_stat_anywhere")).is_same(
		_resource(STATS_DEFAULT))


func test_empty_name_still_falls_back_to_default() -> void:
	# `tooltip_ui.gd` calls this with "" for its generic hint row.
	assert_object(Stats.get_stat_icon("")).is_same(_resource(STATS_DEFAULT))


func _resource(path: String) -> Texture2D:
	return load(path) as Texture2D