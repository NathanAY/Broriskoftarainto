# The splitter: an enemy that spawns smaller copies of itself when it dies.
#
# The split lives in a `SplitOnDeath` node on the enemy scene, not in
# `Enemy.gd`, so an enemy that never splits carries none of that code. The
# node watches the enemy's own death event, the same way the death burst
# does.
#
# The children's stats are scaled before they enter the tree, because
# `Health._ready()` reads the health stat once and never looks again.
class_name EnemySplitOnDeathTest
extends GdUnitTestSuite

const ENEMY_SCENE := "res://src/Systems/Enemy.tscn"
const BOSS_SCENE := "res://src/Systems/EnemyBoss.tscn"
const SPLITTER_SCENE := "res://src/Systems/enemies/SplitOnDeath.tscn"

var _root: Node2D = null
var _container: Node = null


func after_test() -> void:
	if is_instance_valid(_root):
		_root.free()


## An enemy in the container, with a splitter node unless the test asks for a
## plain one.
func _spawn_enemy(with_splitter: bool = true) -> Enemy:
	_root = Node2D.new()
	_root.name = "World"
	add_child(_root)
	_container = Node.new()
	_container.name = "Enemies"
	_root.add_child(_container)
	var enemy: Enemy = load(ENEMY_SCENE).instantiate()
	if with_splitter:
		enemy.add_child(load(SPLITTER_SCENE).instantiate())
	_container.add_child(enemy)
	return enemy


func _splitter(enemy: Enemy) -> SplitOnDeath:
	return enemy.get_node("SplitOnDeath") as SplitOnDeath


func _kill(enemy: Enemy) -> void:
	var health := enemy.get_node("Health") as Health
	var ctx := DamageContext.new()
	ctx.source = enemy
	ctx.target = enemy
	ctx.base_amount = 1000.0
	ctx.final_amount = 1000.0
	ctx.tags.append("melee")
	health.apply_damage(ctx)


## The children in the container, not counting the parent.
func _children_of(original: Enemy) -> Array:
	var out: Array = []
	for child in _container.get_children():
		if child is Enemy and child != original:
			out.append(child)
	return out


func _body_radius(enemy: Enemy) -> float:
	var shape := enemy.get_node("CollisionShape2D") as CollisionShape2D
	return (shape.shape as CircleShape2D).radius


## The children are added with a deferred call, so the tree has to settle
## before they are there.
func _settle() -> void:
	for _i in range(3):
		await get_tree().process_frame


func test_a_splitter_spawns_its_children_when_it_dies() -> void:
	var enemy := _spawn_enemy()
	_splitter(enemy).split_count = 3

	_kill(enemy)
	await _settle()

	assert_int(_children_of(enemy).size()).is_equal(3)


func test_an_enemy_without_a_splitter_spawns_nothing() -> void:
	var enemy := _spawn_enemy(false)

	_kill(enemy)
	await _settle()

	assert_int(_children_of(enemy).size()).is_equal(0)


func test_the_children_do_not_split_again() -> void:
	var enemy := _spawn_enemy()
	_kill(enemy)
	await _settle()

	var children := _children_of(enemy)
	assert_int(children.size()).is_equal(3)
	_kill(children[0] as Enemy)
	await _settle()

	assert_int(_children_of(enemy).size()).is_equal(3)


func test_the_children_are_scaled_down() -> void:
	var enemy := _spawn_enemy()
	var split_scale: float = 0.6
	_splitter(enemy).split_scale = split_scale
	var parent_health: float = enemy.stats.get_stat("health")
	var parent_radius := _body_radius(enemy)

	_kill(enemy)
	await _settle()

	var child := _children_of(enemy)[0] as Enemy
	var child_health := child.get_node("Health") as Health
	# The health is scaled before the child enters the tree, so `Health` has
	# already read the scaled value.
	assert_float(child_health.max_health).is_equal_approx(parent_health * split_scale, 0.001)
	assert_float(_body_radius(child)).is_equal_approx(parent_radius * split_scale, 0.001)
	var sprite := child.get_node("Node2D/Sprite2D") as Sprite2D
	assert_vector(sprite.scale).is_equal_approx(Vector2.ONE * split_scale, Vector2(0.001, 0.001))


func test_scaling_a_child_does_not_shrink_any_other_instance() -> void:
	var enemy := _spawn_enemy()
	var radius_before := _body_radius(enemy)
	var bystander: Enemy = load(ENEMY_SCENE).instantiate()
	_container.add_child(bystander)

	_kill(enemy)
	await _settle()

	# The collider shape is a shared sub-resource of the scene, so a child that
	# shrank it in place would shrink every instance of the enemy.
	assert_float(_body_radius(enemy)).is_equal_approx(radius_before, 0.001)
	assert_float(_body_radius(bystander)).is_equal_approx(radius_before, 0.001)


func test_the_children_are_copies_of_the_owners_own_scene() -> void:
	var enemy := _spawn_enemy()
	# No split scene: the splitter falls back to the owner's own scene, which
	# is the only way a scene can split into itself - a scene cannot point at
	# itself, Godot refuses the cyclic reference.
	_kill(enemy)
	await _settle()

	var children := _children_of(enemy)
	assert_int(children.size()).is_equal(3)
	assert_that((children[0] as Enemy).scene_file_path).is_equal(ENEMY_SCENE)


func test_the_children_can_be_another_scene() -> void:
	var enemy := _spawn_enemy()
	_splitter(enemy).split_scene = load(BOSS_SCENE)

	_kill(enemy)
	await _settle()

	var children := _children_of(enemy)
	assert_int(children.size()).is_equal(3)
	assert_that((children[0] as Enemy).scene_file_path).is_equal(BOSS_SCENE)


func test_the_children_chase_the_same_target() -> void:
	var enemy := _spawn_enemy()
	var prey := Node2D.new()
	add_child(prey)
	enemy.set_target_position(prey)

	_kill(enemy)
	await _settle()

	var child := _children_of(enemy)[0] as Enemy
	assert_object(child.target).is_same(prey)
