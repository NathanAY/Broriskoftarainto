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


func test_burst_spawns_one_node_per_piece() -> void:
	var burst = BURST_SCENE.instantiate()
	add_child(burst)
	var sprite := _make_sprite()
	add_child(sprite)
	burst.configure(sprite, Vector2.RIGHT, 1.0)
	assert_int(burst.get_piece_count()).is_greater(TextureBurst.MIN_CRACKS)
	assert_int(burst.get_child_count()).is_equal(burst.get_piece_count())
	sprite.queue_free()
	burst.queue_free()


func test_burst_pieces_are_textured_polygons() -> void:
	var burst = BURST_SCENE.instantiate()
	add_child(burst)
	var sprite := _make_sprite()
	add_child(sprite)
	burst.configure(sprite, Vector2.LEFT, 2.0)
	for child in burst.get_children():
		var piece := child as Polygon2D
		assert_object(piece).is_not_null()
		assert_object(piece.texture).is_not_null()
		assert_int(piece.polygon.size()).is_greater_equal(3)
		assert_int(piece.uv.size()).is_equal(piece.polygon.size())
	burst.queue_free()
	sprite.queue_free()


## A cracked pane, not a grid: together the pieces tile the whole frame exactly
## (no gap, no overlap), but their sizes and corner counts differ widely.
func test_crack_pieces_tile_the_frame_with_varied_pieces() -> void:
	var size := Vector2(100.0, 80.0)
	for _round in 20:
		var total := 0.0
		var smallest := INF
		var largest := 0.0
		var corner_counts := {}
		for piece in TextureBurst.crack_pieces(size):
			var area := TextureBurst._polygon_area(piece)
			total += area
			smallest = minf(smallest, area)
			largest = maxf(largest, area)
			corner_counts[piece.size()] = true
		assert_float(total).is_equal_approx(size.x * size.y, 1.0)
		assert_float(largest / smallest).is_greater(4.0)
		assert_int(corner_counts.size()).is_greater(1)


## Mirroring the sprite must mirror where the shards sit, or a left-facing enemy
## would shatter into a flipped copy of itself.
func test_burst_flip_h_mirrors_shard_positions() -> void:
	var burst = BURST_SCENE.instantiate()
	add_child(burst)
	var sprite := _make_sprite()
	sprite.flip_h = true
	add_child(sprite)
	burst.configure(sprite, Vector2.RIGHT, 1.0)
	for child in burst.get_children():
		var piece := child as Polygon2D
		var uv_centre := Vector2.ZERO
		for uv in piece.uv:
			uv_centre += uv
		uv_centre /= float(piece.uv.size())
		var expected_x := sprite.texture.get_width() * 0.5 - uv_centre.x
		assert_float(piece.position.x).is_equal_approx(expected_x * sprite.global_transform.get_scale().x, 0.01)
	burst.queue_free()
	sprite.queue_free()


## A huge overkill (1-health enemy, strong hit) must still leave the pieces on
## screen: travel may grow with the boost, but far slower than the boost itself,
## or every piece is gone before it fades.
func test_burst_travel_grows_sublinearly_with_overkill() -> void:
	var low := _mean_travel(1.0)
	var boost := 100.0
	var high := _mean_travel(boost)
	assert_float(high).is_greater(low)
	assert_float(high).is_less(low * boost * 0.5)


func _mean_travel(speed_multiplier: float) -> float:
	var burst = BURST_SCENE.instantiate()
	add_child(burst)
	var sprite := _make_sprite()
	add_child(sprite)
	burst.configure(sprite, Vector2.RIGHT, 1.0, speed_multiplier)
	var start: Array[Vector2] = []
	for child in burst.get_children():
		start.append((child as Node2D).position)
	for _step in 20:
		burst._process(0.05)
	var total := 0.0
	var index := 0
	for child in burst.get_children():
		total += (child as Node2D).position.distance_to(start[index])
		index += 1
	var mean := total / float(index)
	burst.queue_free()
	sprite.queue_free()
	return mean


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
	assert_int(burst.get_piece_count()).is_greater(TextureBurst.MIN_CRACKS)
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
	assert_int(found_burst.get_piece_count()).is_greater(TextureBurst.MIN_CRACKS)
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


func test_manager_hides_ground_shadow_on_death() -> void:
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
	var shadow := Sprite2D.new()
	shadow.name = "Shadow"
	sprite.add_child(shadow)
	holder.add_child(MANAGER_SCENE.instantiate())
	var ctx := DamageContext.new()
	ctx.target = holder
	ctx.target_take_persent_damage = 0.5
	event_manager.emit_event("on_death", {"self": holder, "damage_context": ctx})
	assert_bool(shadow.visible).is_false()
	container.queue_free()
