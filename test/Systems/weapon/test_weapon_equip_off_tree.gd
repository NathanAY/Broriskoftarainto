## Regression cover for the fire timer being started before it is in the scene tree.
##
## `BaseWeapon.apply_to()` used to call `timer.start()` unconditionally. A Timer
## can only tick once it is inside the tree, so when the holder was still
## off-tree that call raised `Unable to start the timer because it's not inside
## the scene tree` *and left the timer stopped for good* - the weapon was
## equipped, looked correct, and never fired. Buying a weapon in the shop hits
## this path, because the shop builds its character off-tree and equips into it
## directly.
##
## The fix waits on the timer's own `tree_entered` and starts from there.
##
## These tests drive `apply_to` against a bare holder so the timer is measured on
## its own, without `WeaponHolder` in the way. The end-to-end version - a real
## detached `Character` equipped with no manual wiring - is in
## `test_weapon_equip_detached_character.gd`, and the holder's own re-entry
## behaviour is in `test_weapon_holder_reentry.gd`.
class_name WeaponEquipOffTreeTest
extends GdUnitTestSuite

const FIST := "res://src/Resources/weapons/Fist.tres"


## A bare holder carrying the two children `apply_to` looks for, built but never
## added to the tree. It is a plain `Node2D` so that nothing else in the weapon
## pipeline can interfere with what is being measured here.
func _off_tree_holder() -> Node2D:
	# Typed explicitly: `auto_free` returns a Variant, and inferring from it is
	# itself a warning, which this project treats as an error.
	var holder: Node2D = auto_free(Node2D.new())
	holder.name = "Holder"
	var event_manager := EventManager.new()
	event_manager.name = "EventManager"
	holder.add_child(event_manager)
	var stats := Stats.new()
	stats.name = "Stats"
	stats.event_manager = event_manager
	holder.add_child(stats)
	return holder


## A fresh fist instance. `BaseWeapon` is a Resource carrying mutable runtime
## state (firing timer, cached damage, bound effect nodes), so the `.tres` must
## never be shared between tests.
func _fist() -> BaseWeapon:
	return load(FIST).duplicate(true) as BaseWeapon


func test_equipping_off_tree_leaves_the_timer_stopped_but_armed() -> void:
	var holder := _off_tree_holder()
	var weapon := _fist()
	weapon.apply_to(holder)

	# Sanity on the fixture: if this fails, every assertion below is measuring the
	# already-live path and the suite is proving nothing.
	assert_bool(holder.is_inside_tree()).override_failure_message(
		"the fixture is supposed to be off-tree").is_false()
	assert_bool(weapon.timer.is_inside_tree()).override_failure_message(
		"a timer on an off-tree holder cannot be in the tree yet").is_false()
	assert_bool(weapon.timer.is_stopped()).override_failure_message(
		"a timer outside the tree cannot be running").is_true()
	# The armed one-shot is the whole mechanism: nothing polls for the holder
	# arriving, so an unarmed timer means the weapon would never fire.
	assert_bool(weapon.timer.tree_entered.is_connected(
		weapon._start_timer_when_holder_enters_tree)).override_failure_message(
		"the deferred start is not armed").is_true()


func test_weapon_equipped_off_tree_fires_once_its_holder_enters_the_tree() -> void:
	var holder := _off_tree_holder()
	var weapon := _fist()
	weapon.apply_to(holder)
	var timer := weapon.timer

	# Entering the tree is what fires the deferred start. Before the fix the timer
	# was left stopped here for good, so this is the assertion that could not be
	# satisfied at all.
	#
	# The signal has to be the timer's own `tree_entered`, not the holder's: Godot
	# emits a parent's `tree_entered` before recursing into its children, so a
	# handler on the holder would still see an off-tree timer and fail exactly as
	# before.
	add_child(holder)
	await await_millis(1)

	assert_bool(timer.is_inside_tree()).override_failure_message(
		"the weapon's timer must ride along on the holder").is_true()
	assert_bool(timer.is_stopped()).override_failure_message(
		"the deferred tree_entered start never reached the timer").is_false()
	assert_float(timer.wait_time).override_failure_message(
		"attack speed was never applied to the timer").is_greater(0.0)


func test_weapon_equipped_on_a_live_holder_starts_immediately() -> void:
	var holder := _off_tree_holder()
	add_child(holder)
	await await_millis(1)
	var weapon := _fist()
	weapon.apply_to(holder)

	# The already-live path must not have picked up latency from the deferred
	# branch, and must not have left the one-shot armed behind it.
	assert_bool(holder.is_inside_tree()).is_true()
	assert_bool(weapon.timer.is_inside_tree()).is_true()
	assert_bool(weapon.timer.is_stopped()).override_failure_message(
		"a weapon equipped on a live holder has to start at once").is_false()
	assert_bool(weapon.timer.tree_entered.is_connected(
		weapon._start_timer_when_holder_enters_tree)).override_failure_message(
		"a timer that is already live must not also wait on tree_entered").is_false()


func test_the_deferred_start_only_fires_once() -> void:
	var holder := _off_tree_holder()
	var weapon := _fist()
	weapon.apply_to(holder)

	add_child(holder)
	await await_millis(1)
	assert_bool(weapon.timer.is_stopped()).is_false()

	# Leaving and re-entering must not stack a second start on top, and the
	# one-shot must have disconnected itself the first time round.
	remove_child(holder)
	add_child(holder)
	await await_millis(1)

	assert_bool(weapon.timer.is_stopped()).override_failure_message(
		"re-entering the tree knocked the running timer out of its running state"
	).is_false()


func test_removing_an_off_tree_weapon_drops_the_pending_tree_entered_start() -> void:
	var holder := _off_tree_holder()
	var weapon := _fist()
	weapon.apply_to(holder)
	var timer := weapon.timer

	weapon.remove_from(holder)

	# The one-shot would otherwise stay wired to a weapon that no longer exists,
	# and fire when the holder eventually arrives.
	assert_bool(timer.tree_entered.is_connected(
		weapon._start_timer_when_holder_enters_tree)).override_failure_message(
		"remove_from left the deferred start connected").is_false()
	assert_bool(timer.is_stopped()).override_failure_message(
		"remove_from left the timer running").is_true()