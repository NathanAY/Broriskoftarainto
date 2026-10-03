## Cover for equipping into a character that has not entered the scene tree.
##
## This is the case the shop runs in: it builds a character, hands it to
## `ShopMenu`, and the buy handler equips a weapon or adds an item into it while
## it is still detached.
##
## That used to require the caller to wire the holder up by hand. `Character`'s
## own refs were `@onready`, so they read as null while detached, and so did
## `WeaponHolder.hold_owner` / `ItemHolder.hold_owner`, which `@onready` tied to
## `_ready`. Every fixture that built an off-tree character therefore had to
## repeat the same three assignments, and forgetting one produced a null-property
## error rather than anything that named the mistake:
##
##     character.stats = character.get_node("Stats")
##     weapon_holder.hold_owner = character
##     weapon_holder.event_manager = character.get_node("EventManager")
##
## All of those resolve on access now, so nothing has to be wired and the ritual
## is gone from the fixtures. These tests pin that, because the failure mode
## without them is silent: everything still works, right up until a caller who
## assumed the old convention stops doing it.
class_name WeaponEquipDetachedCharacterTest
extends GdUnitTestSuite

const FIST := "res://src/Resources/weapons/Fist.tres"
const BOOTS := "res://src/Resources/items/BootsOfSpeed.tres"


## A fully built character that has never entered the tree. Built from the scene
## so the child nodes are exactly what ships.
func _detached_character() -> Character:
	var character: Character = auto_free(
		load("res://src/Systems/Character.tscn").instantiate() as Character)
	assert_bool(character.is_inside_tree()).override_failure_message(
		"the fixture is supposed to be detached").is_false()
	return character


func test_a_detached_character_resolves_its_own_children() -> void:
	var character := _detached_character()

	# These four were all null before, because `@onready` waits for `_ready`.
	assert_object(character.weapon_holder).override_failure_message(
		"weapon_holder read as null while detached; no manual wiring is acceptable"
	).is_not_null()
	assert_object(character.item_holder).is_not_null()
	assert_object(character.stats).is_not_null()
	assert_object(character.event_manager).is_not_null()


func test_a_detached_weapon_holder_resolves_its_owner() -> void:
	var character := _detached_character()
	var holder: WeaponHolder = character.weapon_holder

	# `hold_owner` used to need `holder.hold_owner = character` by hand.
	assert_object(holder.hold_owner).override_failure_message(
		"hold_owner read as null while detached").is_same(character)
	assert_object(holder.event_manager).override_failure_message(
		"event_manager read as null while detached; it must resolve off the owner"
	).is_same(character.event_manager)


func test_a_detached_item_holder_resolves_its_owner_and_stats() -> void:
	var character := _detached_character()
	var holder: ItemHolder = character.item_holder

	assert_object(holder.hold_owner).override_failure_message(
		"hold_owner read as null while detached").is_same(character)
	assert_object(holder.stats).override_failure_message(
		"stats read as null while detached; it must resolve off the owner"
	).is_same(character.stats)
	assert_object(holder.event_manager).is_same(character.event_manager)


func test_a_weapon_can_be_equipped_into_a_detached_character_with_no_wiring() -> void:
	var character := _detached_character()

	character.weapon_holder.add_weapon(load(FIST).duplicate(true))

	var holder: WeaponHolder = character.weapon_holder
	assert_int(holder.weapons.size()).is_equal(1)
	var weapon: BaseWeapon = holder.weapons[0]
	assert_object(weapon.timer).override_failure_message(
		"apply_to needs hold_owner to build the timer").is_not_null()
	assert_object(weapon.get_holder()).override_failure_message(
		"the weapon did not record its holder").is_same(character)
	# Detached, so it cannot be running yet - `test_weapon_equip_off_tree.gd`
	# covers what happens when the character then enters the tree.
	assert_bool(weapon.timer.is_inside_tree()).is_false()


func test_an_item_can_be_added_to_a_detached_character_with_no_wiring() -> void:
	var character := _detached_character()

	character.item_holder.add_item(load(BOOTS))

	var holder: ItemHolder = character.item_holder
	assert_int(holder.items.size()).is_equal(1)
	# The item's own node is built under the holder, which works detached, and
	# `apply_to` reached Stats through `hold_owner` - proven by the modifier having
	# been able to register itself. Matched by type, not name: the node is named
	# after the item ("Boots of Speed"), so `find_child("ItemNode")` would miss it.
	var item_node: ItemNode = null
	for child in holder.get_children():
		if child is ItemNode:
			item_node = child
			break
	assert_object(item_node).override_failure_message(
		"the item's node was not created under the holder").is_not_null()


func test_the_holder_still_resolves_correctly_once_the_character_is_live() -> void:
	var character := _detached_character()
	add_child(character)
	await await_millis(1)

	# The getters must not be a trick that only works off-tree.
	assert_bool(character.is_inside_tree()).is_true()
	assert_object(character.weapon_holder.hold_owner).is_same(character)
	assert_object(character.item_holder.hold_owner).is_same(character)
	assert_object(character.weapon_holder.event_manager).is_same(character.event_manager)


func test_detaching_the_holder_from_its_owner_reads_as_null_not_stale() -> void:
	# A field cached at `_ready` would keep pointing at the old owner after a
	# detach or a re-parent. Resolving per access reports the truth, which is what
	# every caller already guards for.
	var character := Character.new()
	character.name = "Owner"
	var holder := WeaponHolder.new()
	holder.name = "WeaponHolder"
	character.add_child(holder)
	assert_object(holder.hold_owner).is_same(character)

	character.remove_child(holder)

	assert_object(holder.hold_owner).override_failure_message(
		"hold_owner kept pointing at a parent the holder is no longer under"
	).is_null()
	assert_object(holder.event_manager).override_failure_message(
		"event_manager must resolve to null once there is no owner to ask"
	).is_null()

	# The holder is detached now, so freeing the owner will not reach it: both have
	# to be released by hand.
	holder.free()
	character.free()