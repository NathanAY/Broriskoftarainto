extends MeshInstance2D
## Sizes the gate surface to the portal sprite so the shader's circular mask
## lines up with the hole in the art.
##
## The quad takes the sprite's canvas size *and* the sprite's scale, so the disc
## covers exactly the rect the art is drawn in however large that art is. Both
## are read from the sibling `Sprite2D` rather than authored a second time.


func _ready() -> void:
	var sprite := get_parent().get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.texture == null:
		return
	var quad := mesh as QuadMesh
	if quad == null:
		return
	# A scene instance shares its sub-resources with every other instance, so
	# two loop portals would otherwise write the same QuadMesh. Duplicate first.
	quad = quad.duplicate() as QuadMesh
	quad.size = sprite.texture.get_size()
	mesh = quad
	scale = sprite.scale
