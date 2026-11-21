# Orbit slots: odd counts always have one weapon at bottom centre, even counts never do.
extends GdUnitTestSuite

func _dir(i: int, n: int) -> Vector2:
	var a := WeaponHolder.slot_angle(i, n)
	return Vector2(cos(a), sin(a))


func test_odd_counts_have_exactly_one_weapon_at_bottom_and_are_symmetric() -> void:
	for n in [1, 3, 5, 7]:
		var at_bottom := 0
		var sum := Vector2.ZERO
		for i in n:
			var d := _dir(i, n)
			sum += d
			if d.is_equal_approx(Vector2.DOWN):
				at_bottom += 1
			# mirror image across the vertical axis is also a slot
			var mirrored := false
			for j in n:
				if _dir(j, n).is_equal_approx(Vector2(-d.x, d.y)):
					mirrored = true
			assert_bool(mirrored).is_true()
		assert_int(at_bottom).is_equal(1)
		if n > 1:
			assert_float(sum.length()).is_less(0.001)


func test_even_counts_have_no_weapon_at_bottom() -> void:
	for n in [2, 4, 6, 8]:
		for i in n:
			assert_bool(_dir(i, n).is_equal_approx(Vector2.DOWN)).is_false()


func test_two_is_left_right_and_four_is_an_x() -> void:
	assert_bool(_dir(0, 2).is_equal_approx(Vector2.LEFT)).is_true()
	assert_bool(_dir(1, 2).is_equal_approx(Vector2.RIGHT)).is_true()
	for i in 4:
		var d := _dir(i, 4)
		assert_float(absf(d.x)).is_equal_approx(absf(d.y), 0.001)


func test_six_has_left_and_right_plus_four_diagonals() -> void:
	var horizontal := 0
	for i in 6:
		var d := _dir(i, 6)
		if absf(d.y) < 0.001:
			horizontal += 1
	assert_int(horizontal).is_equal(2)
