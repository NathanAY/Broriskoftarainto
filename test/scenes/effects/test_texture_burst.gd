# GdUnit generated TestSuite
class_name TextureBurstTest
extends GdUnitTestSuite

const BURST_SCENE: PackedScene = preload("res://src/Scenes/effects/TextureBurst.tscn")
const MANAGER_SCENE: PackedScene = preload("res://src/Scenes/effects/TextureBurstManager.tscn")


func _make_sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load("res://src/Assets/enemies/spitter.png")
	sprite.centered = true
	return sprite


func test_burst_spawns_32_pieces() -> void:
	var burst = BURST_SCENE.instantiate()
	add_child(burst)
	var sprite := _make_sprite()
	add_child(sprite)
	burst.configure(sprite, Vector2.RIGHT, 1.0)
	assert_int(burst.get_piece_count()).is_equal(32)
	assert_int(burst.get_child_count()).is_equal(32)
	sprite.queue_free()
	burst.queue_free()


func test_burst_pieces_use_atlas_slices() -> void:
	var burst = BURST_SCENE.instantiate()
	add_child(burst)
	var sprite := _make_sprite()
	add_child(sprite)
	burst.configure(sprite, Vector2.LEFT, 2.0)
	for child in burst.get_children():
		assert_object(child).is_not_null()
		var piece := child as Sprite2D
		assert_object(piece).is_not_null()
		assert_object(piece.texture).is_instanceof(AtlasTexture)
	burst.queue_free()
	sprite.queue_free()


func test_burst_null_texture_is_safe() -> void:
	var burst = BURST_SCENE.instantiate()
	add_child(burst)
	var sprite := Sprite2D.new()
	add_child(sprite)
	burst.configure(sprite, Vector2.RIGHT, 1.0)
	assert_int(burst.get_piece_count()).is_equal(0)
	sprite.queue_free()
	burst.queue_free()


func test_burst_zero_direction_falls_back() -> void:
	var burst = BURST_SCENE.instantiate()
	add_child(burst)
	var sprite := _make_sprite()
	add_child(sprite)
	burst.configure(sprite, Vector2.ZERO, 1.0)
	assert_int(burst.get_piece_count()).is_equal(32)
	burst.queue_free()
	sprite.queue_free()


func test_burst_weak_damage_keeps_base_speed() -> void:
	var burst = BURST_SCENE.instantiate()
	add_child(burst)
	var sprite := _make_sprite()
	add_child(sprite)
	burst.configure(sprite, Vector2.RIGHT, 1.0, 1.0)
	assert_float(burst.get_speed_multiplier()).is_equal(1.0)
	burst.queue_free()
	sprite.queue_free()


func test_burst_strong_damage_scales_speed() -> void:
	var burst = BURST_SCENE.instantiate()
	add_child(burst)
	var sprite := _make_sprite()
	add_child(sprite)
	burst.configure(sprite, Vector2.RIGHT, 1.0, 10.0)
	assert_float(burst.get_speed_multiplier()).is_equal(10.0)
	burst.queue_free()
	sprite.queue_free()


func test_manager_spawns_burst_as_sibling_on_death() -> void:
	var container := Node2D.new()
	add_child(container)
	var holder := Node2D.new()
	holder.name = "Holder"
	container.add_child(holder)
	var event_manager := EventManager.new()
	event_manager.name = "EventManager"
	holder.add_child(event_manager)
	var inner := Node2D.new()
	inner.name = "Node2D"
	holder.add_child(inner)
	var sprite := _make_sprite()
	sprite.name = "Sprite2D"
	inner.add_child(sprite)
	var manager = MANAGER_SCENE.instantiate()
	holder.add_child(manager)
	var ctx := DamageContext.new()
	ctx.source = null
	ctx.target = holder
	ctx.target_take_persent_damage = 0.5
	event_manager.emit_event("on_death", {"self": holder, "damage_context": ctx})
	# Burst must be added to the container (sibling of holder), not inside holder,
	# so it survives the owner's queue_free.
	var found_burst = null
	for child in container.get_children():
		if child != holder and child.has_method("get_piece_count"):
			found_burst = child
	assert_object(found_burst).is_not_null()
	assert_int(found_burst.get_piece_count()).is_equal(32)
	container.queue_free()


func test_manager_weak_damage_keeps_base_burst_speed() -> void:
	var found_burst = _spawn_death_burst(0.5)
	assert_object(found_burst).is_not_null()
	assert_float(found_burst.get_speed_multiplier()).is_equal(1.0)

func test_manager_three_times_max_health_is_ten_times_speed() -> void:
	var found_burst = _spawn_death_burst(3.0)
	assert_object(found_burst).is_not_null()
	assert_float(found_burst.get_speed_multiplier()).is_equal(10.0)

func test_manager_overkill_speed_has_no_cap() -> void:
	var found_burst = _spawn_death_burst(6.0)
	assert_object(found_burst).is_not_null()
	assert_float(found_burst.get_speed_multiplier()).is_equal(23.5)


func _spawn_death_burst(percent: float) -> Node:
	var container := Node2D.new()
	add_child(container)
	var holder := Node2D.new()
	holder.name = "Holder"
	container.add_child(holder)
	var event_manager := EventManager.new()
	event_manager.name = "EventManager"
	holder.add_child(event_manager)
	var inner := Node2D.new()
	inner.name = "Node2D"
	holder.add_child(inner)
	var sprite := _make_sprite()
	sprite.name = "Sprite2D"
	inner.add_child(sprite)
	var manager = MANAGER_SCENE.instantiate()
	holder.add_child(manager)
	var ctx := DamageContext.new()
	ctx.source = null
	ctx.target = holder
	ctx.target_take_persent_damage = percent
	event_manager.emit_event("on_death", {"self": holder, "damage_context": ctx})
	var found_burst = null
	for child in container.get_children():
		if child != holder and child.has_method("get_speed_multiplier"):
			found_burst = child
	container.queue_free()
	return found_burst
