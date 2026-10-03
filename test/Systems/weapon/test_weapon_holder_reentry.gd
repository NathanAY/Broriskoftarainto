## Regression cover for `WeaponHolder._ready()` re-running on every tree entry.
##
## `_ready()` used to be:
##
##     for w in weapons:
##         add_weapon(w)
##
## while `add_weapon` appends the live instance it creates back onto `weapons`.
## Two things went wrong at once:
##
##   1. A GDScript `for` over an Array re-reads the size each pass, so an append
##      inside the loop body extends the loop. Each pass added exactly one more
##      element for the loop to find, so a holder entering the tree with any
##      weapon equipped looped forever and hung the game.
##   2. Even setting the loop aside, every already-equipped weapon would be
##      equipped a second time, because `add_weapon` had already put the live
##      instances into the very array `_ready` was iterating.
##
## The holder now records what it has equipped in `equipped`, and the equipping
## pass iterates a snapshot and skips anything already recorded.
##
## The pass also runs deferred out of `_ready`. That is the second half of the
## same story: `_ready` runs while the parent is mid-way through propagating tree
## entry, so `apply_to`'s `holder.add_child(timer)` failed with "Parent node is
## busy setting up children" and a pre-placed weapon was left equipped with no
## firing timer. The `pre_placed` tests below cover that.
class_name WeaponHolderReentryTest
extends GdUnitTestSuite

const FIST := "res://src/Resources/weapons/Fist.tres"


## A holder with the children `apply_to` looks for, plus a weapon already
## equipped into it while it was off-tree - which is what a character being taken
## out of the tree and put back looks like from the holder's point of view.
func _detached_holder_with_a_weapon() -> Array:
	var root := Node2D.new()
	root.name = "Root"
	var event_manager := EventManager.new()
	event_manager.name = "EventManager"
	root.add_child(event_manager)
	var stats := Stats.new()
	stats.name = "Stats"
	stats.event_manager = event_manager
	root.add_child(stats)

	var holder := WeaponHolder.new()
	holder.name = "WeaponHolder"
	root.add_child(holder)
	# No wiring: `hold_owner` and `event_manager` resolve on access, so they are
	# already correct while `root` is still detached.

	holder.add_weapon(load(FIST).duplicate(true))
	return [auto_free(root), holder] as Array


func test_entering_the_tree_does_not_equip_an_already_equipped_weapon_again() -> void:
	var parts := _detached_holder_with_a_weapon()
	var root: Node2D = parts[0]
	var holder: WeaponHolder = parts[1]
	var equipped_before: BaseWeapon = holder.weapons[0]

	assert_int(holder.weapons.size()).override_failure_message(
		"fixture should be holding exactly one weapon").is_equal(1)

	add_child(root)
	await await_millis(1)

	# Before the fix this line was never reached: `_ready` looped until the runner
	# timed out.
	assert_int(holder.weapons.size()).override_failure_message(
		"_ready re-equipped the weapon, so the holder now holds duplicates").is_equal(1)
	assert_object(holder.weapons[0]).override_failure_message(
		"the holder should still be holding the same instance, not a fresh copy"
	).is_same(equipped_before)
	assert_int(holder.equipped.size()).override_failure_message(
		"the equipped record and the weapons list have drifted apart").is_equal(1)


func test_leaving_and_re_entering_repeatedly_never_grows_the_weapon_list() -> void:
	var parts := _detached_holder_with_a_weapon()
	var root: Node2D = parts[0]
	var holder: WeaponHolder = parts[1]

	# The loop hazard compounds per entry, so a couple of round trips is enough to
	# prove `_ready` is now idempotent rather than merely slow.
	for _cycle in 3:
		add_child(root)
		await await_millis(1)
		remove_child(root)

	assert_int(holder.weapons.size()).override_failure_message(
		"repeated tree entries changed the weapon count").is_equal(1)


func test_two_weapons_survive_a_re_entry_without_growing() -> void:
	var parts := _detached_holder_with_a_weapon()
	var root: Node2D = parts[0]
	var holder: WeaponHolder = parts[1]
	holder.add_weapon(load("res://src/Resources/weapons/Pistol.tres").duplicate(true))
	assert_int(holder.weapons.size()).is_equal(2)

	add_child(root)
	await await_millis(1)

	assert_int(holder.weapons.size()).override_failure_message(
		"re-entry duplicated the weapon set").is_equal(2)


func test_removing_a_weapon_clears_its_equipped_record() -> void:
	# The root is never needed here: this is about the two records, not the tree.
	var holder: WeaponHolder = _detached_holder_with_a_weapon()[1]
	var weapon: BaseWeapon = holder.weapons[0]

	holder.remove_weapon(weapon)

	assert_int(holder.weapons.size()).is_equal(0)
	# A stale record would make a later tree entry treat the freed instance as
	# live, and the weapons list would drift away from the record.
	assert_int(holder.equipped.size()).override_failure_message(
		"remove_weapon left the weapon in the equipped record").is_equal(0)
	assert_bool(holder.equipped.has(weapon)).override_failure_message(
		"the removed instance is still marked equipped").is_false()


func test_a_weapon_added_after_removal_is_equipped_normally_on_re_entry() -> void:
	var parts := _detached_holder_with_a_weapon()
	var root: Node2D = parts[0]
	var holder: WeaponHolder = parts[1]
	holder.remove_weapon(holder.weapons[0])
	holder.add_weapon(load(FIST).duplicate(true))
	var live: BaseWeapon = holder.weapons[0]

	add_child(root)
	await await_millis(1)

	assert_int(holder.weapons.size()).override_failure_message(
		"the freshly added weapon was re-equipped on tree entry").is_equal(1)
	assert_object(holder.weapons[0]).is_same(live)


func test_equipping_from_add_weapon_is_never_blocked_by_the_record() -> void:
	# `add_weapon` always hands out a fresh duplicate, so an instance can never be
	# handed to it twice; this pins that the record is written per instance and
	# does not accidentally gate the runtime equip path.
	var parts := _detached_holder_with_a_weapon()
	var holder: WeaponHolder = parts[1]

	holder.add_weapon(load(FIST).duplicate(true))
	holder.add_weapon(load(FIST).duplicate(true))

	assert_int(holder.weapons.size()).is_equal(3)
	assert_int(holder.equipped.size()).is_equal(3)


# --- the editor-populated `weapons` export ------------------------------------


## A holder carrying one weapon in its exported `weapons` array, which is what
## pre-placing a weapon in the editor produces.
func _holder_with_a_pre_placed_weapon() -> Array:
	var root := Node2D.new()
	root.name = "Root"
	var event_manager := EventManager.new()
	event_manager.name = "EventManager"
	root.add_child(event_manager)
	var stats := Stats.new()
	stats.name = "Stats"
	stats.event_manager = event_manager
	root.add_child(stats)

	var holder := WeaponHolder.new()
	holder.name = "WeaponHolder"
	holder.weapons = [load(FIST).duplicate(true)]
	root.add_child(holder)
	return [auto_free(root), holder] as Array


func test_a_pre_placed_weapon_ends_up_equipped_with_a_running_timer() -> void:
	var parts := _holder_with_a_pre_placed_weapon()
	var root: Node2D = parts[0]
	var holder: WeaponHolder = parts[1]
	# The template starts life in the list; `add_weapon` duplicates it, so the
	# holder ends up with one *live* weapon, not the template.
	var template: BaseWeapon = holder.weapons[0]

	add_child(root)
	# Two frames: one for the deferred pass, one for the timer to settle.
	await await_millis(1)
	await await_millis(1)

	assert_int(holder.weapons.size()).override_failure_message(
		"the pre-placed template was not replaced by exactly one live weapon"
	).is_equal(1)
	var live: BaseWeapon = holder.weapons[0]
	assert_object(live).override_failure_message(
		"the template should have been consumed, not equipped in place").is_not_same(template)

	# The part that used to fail: `add_child(timer)` on a parent that was still
	# setting up children. A timer that exists but never entered the tree leaves
	# the weapon permanently unable to fire.
	assert_object(live.timer).override_failure_message(
		"apply_to never produced a firing timer").is_not_null()
	assert_bool(live.timer.is_inside_tree()).override_failure_message(
		"the timer never made it into the tree, so this weapon cannot fire").is_true()
	assert_bool(live.timer.is_stopped()).override_failure_message(
		"the timer is in the tree but not running, so this weapon cannot fire").is_false()


func test_a_pre_placed_weapon_is_equipped_exactly_once_across_re_entries() -> void:
	var parts := _holder_with_a_pre_placed_weapon()
	var root: Node2D = parts[0]
	var holder: WeaponHolder = parts[1]

	add_child(root)
	await await_millis(1)
	await await_millis(1)
	remove_child(root)
	add_child(root)
	await await_millis(1)
	await await_millis(1)

	# The template is erased once consumed, so a later pass finds only the live
	# weapon, which is already in `equipped` and therefore skipped.
	assert_int(holder.weapons.size()).override_failure_message(
		"re-entry equipped the pre-placed weapon a second time").is_equal(1)
	assert_int(holder.equipped.size()).is_equal(1)