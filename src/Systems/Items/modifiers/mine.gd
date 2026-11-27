extends Area2D
class_name Mine
## A mine the Miner's `MinerMineModifier` lays: the shots his weapons would have
## fired, waiting on the ground. The first enemy body that touches it fires them
## all at once in random directions, then the mine is gone.

## Enemy bodies sit on physics layer 2 (`Enemy.gd` sets `collision_layer = 2`).
const ENEMY_BODY_MASK := 2
## Cut from `docs/plans/images/mines/mines_1.png` by `extract_character_parts.gd`.
const ART := preload("res://src/Assets/character/miner/miner_mine.png")

## `[ProjectileWeapon, count]` pairs packed when the mine was laid. A weapon sold
## since then spawns nothing: `spawn_projectile` needs a holder.
var charges: Array = []
## Multiplies each projectile's damage, which the weapon reads live at detonation.
var damage_multiplier: float = 1.0
## Trigger radius in pixels; also the drawn size.
var radius: float = 30.0

var _spent: bool = false


func _ready() -> void:
	z_index = -1  # under the bodies that walk over it
	collision_layer = 0
	collision_mask = ENEMY_BODY_MASK
	var circle := CircleShape2D.new()
	circle.radius = radius
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	# The art fills its canvas edge to edge, so this scale draws the mine exactly
	# as wide as the circle that triggers it.
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = ART
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.scale = Vector2.ONE * (radius * 2.0 / ART.get_width())
	add_child(sprite)


## Deferred: this runs during the physics flush, where adding the projectiles'
## Area2Ds is refused. `_spent` stops a second body in the same frame firing twice.
func _on_body_entered(body: Node) -> void:
	if not _spent and body.is_in_group("enemies"):
		_spent = true
		detonate.call_deferred()


## Fires every packed projectile from the mine's centre in a random direction.
func detonate() -> void:
	for charge in charges:
		var weapon: ProjectileWeapon = charge[0]
		if not weapon.attack_sound.is_empty():
			SoundManager.play(weapon.attack_sound.pick_random(), -20, 0.2)
		for i in int(charge[1]):
			var p := weapon.spawn_projectile(global_position, Vector2.RIGHT.rotated(randf() * TAU))
			if p == null:
				break
			p.damage *= damage_multiplier
	queue_free()
