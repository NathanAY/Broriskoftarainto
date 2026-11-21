# GdUnit tests for the heal drop: touching it restores a fraction of max health
# (never past max) and consumes it; other bodies leave it alone.
class_name HealPickupTest
extends GdUnitTestSuite

const HEAL_SCENE := "res://src/Systems/Items/HealPickup.tscn"


func _setup() -> Dictionary:
	var runner := scene_runner("res://test/TestScene.tscn")
	var test_scene := runner.scene()
	get_tree().current_scene = test_scene
	var character: Character = test_scene.get_node("Character")
	var pickup: Area2D = load(HEAL_SCENE).instantiate()
	test_scene.add_child(pickup)
	return {"test_scene": test_scene, "character": character, "pickup": pickup}


func test_pickup_heals_fraction_of_max_health_and_is_consumed() -> void:
	var ctx := _setup()
	var character: Character = ctx["character"]
	var pickup = ctx["pickup"]
	var health: Health = character.get_node("Health")
	health.current_health = 1.0
	var expected: float = 1.0 + health.max_health * pickup.heal_fraction + pickup.heal_flat

	pickup._on_body_entered(character)

	assert_float(health.current_health).is_equal_approx(expected, 0.001)
	assert_bool(pickup.is_queued_for_deletion()).is_true()
	ctx["test_scene"].free()


func test_heal_never_exceeds_max_health() -> void:
	var ctx := _setup()
	var character: Character = ctx["character"]
	var health: Health = character.get_node("Health")
	health.current_health = health.max_health

	ctx["pickup"]._on_body_entered(character)

	assert_float(health.current_health).is_equal(health.max_health)
	ctx["test_scene"].free()


func test_non_character_body_does_not_consume_pickup() -> void:
	var ctx := _setup()
	var other: Node2D = auto_free(Node2D.new())
	var pickup = ctx["pickup"]

	pickup._on_body_entered(other)

	assert_bool(pickup.is_queued_for_deletion()).is_false()
	ctx["test_scene"].free()
