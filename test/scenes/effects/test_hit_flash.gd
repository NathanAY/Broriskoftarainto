# GdUnit generated TestSuite
class_name HitFlashManagerTest
extends GdUnitTestSuite

const MANAGER_SCENE: PackedScene = preload("res://src/Scenes/effects/HitFlashManager.tscn")

var _holder: Node2D = null
var _event_manager: EventManager = null
var _sprite: Sprite2D = null
var _manager: Node2D = null


func before_test() -> void:
	_holder = Node2D.new()
	add_child(_holder)
	_event_manager = EventManager.new()
	_event_manager.name = "EventManager"
	_holder.add_child(_event_manager)
	var inner := Node2D.new()
	inner.name = "Node2D"
	_holder.add_child(inner)
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite2D"
	inner.add_child(_sprite)
	_manager = MANAGER_SCENE.instantiate()
	_holder.add_child(_manager)


func after_test() -> void:
	if is_instance_valid(_holder):
		_holder.queue_free()


func _color_for(tags: Array[String]) -> Color:
	var ctx := DamageContext.new()
	ctx.tags = tags
	return _manager._color_for(ctx)


func test_poison_damage_flashes_green() -> void:
	assert_bool(_color_for(["poison"]).is_equal_approx(Color(0.2, 1.8, 0.4))).is_true()


func test_melee_damage_flashes_red() -> void:
	assert_bool(_color_for(["melee"]).is_equal_approx(Color(1.8, 0.2, 0.2))).is_true()


func test_contact_damage_flashes_red() -> void:
	assert_bool(_color_for(["contact"]).is_equal_approx(Color(1.8, 0.2, 0.2))).is_true()


func test_explosion_damage_flashes_yellow() -> void:
	assert_bool(_color_for(["explosion"]).is_equal_approx(Color(1.8, 1.6, 0.2))).is_true()


func test_ranged_damage_flashes_white() -> void:
	assert_bool(_color_for(["projectile"]).is_equal_approx(Color(1.6, 1.6, 1.6))).is_true()


func test_poison_damage_type_flashes_green() -> void:
	var ctx := DamageContext.new()
	ctx.damage_type = "poison"
	assert_bool(_manager._color_for(ctx).is_equal_approx(Color(0.2, 1.8, 0.4))).is_true()


func test_unknown_damage_flashes_white() -> void:
	assert_bool(_color_for([]).is_equal_approx(Color(1.6, 1.6, 1.6))).is_true()


func test_emitting_poison_damage_tints_sprite_green() -> void:
	var ctx := DamageContext.new()
	ctx.tags.append("poison")
	_event_manager.emit_event("before_take_damage", {"damage_context": ctx})
	for i in 6:
		await get_tree().process_frame
	assert_bool(_sprite.modulate.g > _sprite.modulate.r and _sprite.modulate.g > _sprite.modulate.b).is_true()


func test_emitting_melee_damage_tints_sprite_red() -> void:
	var ctx := DamageContext.new()
	ctx.tags.append("melee")
	_event_manager.emit_event("before_take_damage", {"damage_context": ctx})
	for i in 6:
		await get_tree().process_frame
	assert_bool(_sprite.modulate.r > _sprite.modulate.g and _sprite.modulate.r > _sprite.modulate.b).is_true()


func test_emitting_explosion_damage_tints_sprite_yellow() -> void:
	var ctx := DamageContext.new()
	ctx.tags.append("explosion")
	_event_manager.emit_event("before_take_damage", {"damage_context": ctx})
	for i in 6:
		await get_tree().process_frame
	assert_bool(_sprite.modulate.r > _sprite.modulate.b and _sprite.modulate.g > _sprite.modulate.b).is_true()


func test_emitting_ranged_damage_tints_sprite_bright_white() -> void:
	var ctx := DamageContext.new()
	ctx.tags.append("projectile")
	_event_manager.emit_event("before_take_damage", {"damage_context": ctx})
	for i in 6:
		await get_tree().process_frame
	assert_bool(_sprite.modulate.r > 1.0 and _sprite.modulate.g > 1.0 and _sprite.modulate.b > 1.0).is_true()


func test_emitting_before_take_damage_starts_flash_tween() -> void:
	var ctx := DamageContext.new()
	_event_manager.emit_event("before_take_damage", {"damage_context": ctx})
	for i in 8:
		await get_tree().process_frame
	assert_bool(not _sprite.modulate.is_equal_approx(Color.WHITE)).is_true()


func test_flash_always_restores_white_after_full_duration() -> void:
	var ctx := DamageContext.new()
	_event_manager.emit_event("before_take_damage", {"damage_context": ctx})
	for i in 120:
		await get_tree().process_frame
	assert_bool(_sprite.modulate.is_equal_approx(Color(1, 1, 1, 1))).is_true()