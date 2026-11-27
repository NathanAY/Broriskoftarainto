class_name FloatingNumberTest
extends GdUnitTestSuite

# Damage text rules: one decimal below FloatingNumber.DECIMAL_BELOW, whole
# numbers at or above it, a `!` and a bigger size for a crit.

const SCENE := "res://src/ui/numberspawn/FloatingNumber.tscn"


func _spawn() -> FloatingNumber:
	var number: FloatingNumber = auto_free(load(SCENE).instantiate())
	add_child(number)
	return number


func test_damage_below_the_threshold_shows_one_decimal() -> void:
	var number := _spawn()

	number.show_damage(3.24)

	assert_str(number.label.text).is_equal("3.2")


func test_a_whole_damage_below_the_threshold_drops_the_zero_decimal() -> void:
	var number := _spawn()

	number.show_damage(3.0)

	assert_str(number.label.text).is_equal("3")


func test_damage_at_or_above_the_threshold_shows_a_whole_number() -> void:
	var number := _spawn()

	number.show_damage(FloatingNumber.DECIMAL_BELOW + 0.5)

	assert_str(number.label.text).is_equal(str(int(FloatingNumber.DECIMAL_BELOW)))


func test_crit_adds_a_bang_and_is_drawn_bigger() -> void:
	var plain := _spawn()
	plain.show_damage(3.24)
	var crit := _spawn()
	crit.show_damage(3.24, true)

	assert_str(crit.label.text).is_equal("3.2!")
	assert_float(crit.scale.x).is_equal_approx(plain.scale.x * FloatingNumber.CRIT_SCALE, 0.001)
	assert_float(crit.scale.x).is_greater(plain.scale.x)
