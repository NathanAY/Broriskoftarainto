extends Node2D

## Dev-only fixture: the poison bubbles on a row of grunts at a spread of stack
## counts, on arena-floor tan. The effect loops, so pass enough frames for the
## first bubbles to be in the air:
##
##     run_scene_shot.bat res://test/tools/poison_preview.tscn res://poison_shot.png 60
##
## Not part of the game: nothing loads this scene.

const PARTICLES_SCENE: PackedScene = preload("res://src/Scenes/particles/poison_particles.tscn")
const BODY_TEXTURE: Texture2D = preload("res://src/Assets/enemies/spitter.png")

const SAMPLE_STACKS := [1, 3, 6, 10]
const SPACING := 220.0
const BACKDROP := Color(0.78, 0.71, 0.58)


func _ready() -> void:
	var view := get_viewport_rect().size
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.size = view
	add_child(backdrop)
	for index in SAMPLE_STACKS.size():
		var x := view.x * 0.5 + (index - (SAMPLE_STACKS.size() - 1) * 0.5) * SPACING
		_add_body(SAMPLE_STACKS[index], Vector2(x, view.y * 0.5))


## The `Node2D/Sprite2D` layout every actor scene has, without the actor: a real
## enemy would walk off and attack during the settle frames.
func _add_body(stacks: int, at: Vector2) -> void:
	var body := Node2D.new()
	body.position = at
	add_child(body)
	var inner := Node2D.new()
	inner.name = "Node2D"
	body.add_child(inner)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = BODY_TEXTURE
	inner.add_child(sprite)
	var particles: PoisonParticles = PARTICLES_SCENE.instantiate()
	body.add_child(particles)
	particles.set_stacks(stacks)
	var label := Label.new()
	label.text = "%d stacks" % stacks
	label.add_theme_color_override("font_color", Color.BLACK)
	label.position = at + Vector2(-35.0, 70.0)
	add_child(label)
