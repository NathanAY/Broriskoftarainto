# GdUnit TestSuite for the ground shadow under every roster enemy. The shadow is a
# child of the rig `Node2D/Sprite2D`, the node the idle and move animations scale,
# so it grows with the body. The roster fit scale sits on the `Node2D` container
# above it, so the shadow follows the fitted size too.
class_name EnemyShadowTest
extends GdUnitTestSuite

const ENEMY_DIR := "res://src/Systems/enemies"
const SHIELDBEARER_SCENE := "res://src/Systems/enemies/EnemyShieldbearer.tscn"


func test_every_roster_enemy_has_a_translucent_oval_shadow_on_its_rig() -> void:
	var paths := _enemy_scene_paths()
	assert_int(paths.size()).is_greater(0)
	for path in paths:
		var enemy: Node = load(path).instantiate()
		add_child(enemy)
		await get_tree().process_frame

		var shadow := enemy.get_node_or_null("Node2D/Sprite2D/Shadow") as Sprite2D
		assert_that(shadow).override_failure_message("%s has no shadow on its rig" % path).is_not_null()
		if shadow != null:
			assert_float(shadow.modulate.a).is_greater(0.0).is_less(1.0)
			assert_float(shadow.scale.y).is_less(shadow.scale.x)
			assert_bool(shadow.show_behind_parent).override_failure_message(
				"%s shadow would draw over the body" % path).is_true()

		enemy.free()


func test_shadow_scales_with_the_animated_rig() -> void:
	# The mechanic the idle/move animation relies on: scaling the rig scales the
	# shadow with it, so the shadow's on-screen size is a function of the rig's.
	var enemy: Node = load(SHIELDBEARER_SCENE).instantiate()
	add_child(enemy)
	await get_tree().process_frame

	var rig := enemy.get_node("Node2D/Sprite2D") as Sprite2D
	var shadow := rig.get_node("Shadow") as Sprite2D
	var rig_scale_before := rig.scale.x
	var shadow_scale_before := shadow.global_scale.x
	rig.scale = Vector2.ONE * (rig_scale_before * 2.0)
	assert_float(shadow.global_scale.x).is_equal_approx(shadow_scale_before * 2.0, 0.0001)

	enemy.free()


## Every roster enemy scene: `Enemy*.tscn` directly under the enemies folder.
func _enemy_scene_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	var dir := DirAccess.open(ENEMY_DIR)
	if dir == null:
		return paths
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("Enemy") and entry.ends_with(".tscn"):
			paths.append(ENEMY_DIR.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	return paths
