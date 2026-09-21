# GdUnit generated TestSuite
class_name HitFlashManagerTest
extends GdUnitTestSuite

const MANAGER_SCENE: PackedScene = preload("res://src/Scenes/effects/HitFlashManager.tscn")

var _holder: Node2D = null
var _event_manager: EventManager = null
var _sprite: Sprite2D = null


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
	var manager = MANAGER_SCENE.instantiate()
	_holder.add_child(manager)


func after_test() -> void:
	if is_instance_valid(_holder):
		_holder.queue_free()


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