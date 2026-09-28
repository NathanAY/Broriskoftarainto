# The node that stands in for an equipped weapon in the scene tree.
#
# A weapon is a Resource, so it can never be a child itself - this is the one
# node per weapon that makes it visible, selectable and inspectable while the
# game runs. It is a Sprite2D because the holder positions, rotates and flips it
# to orbit the holder, and because every weapon script already works through
# `BaseWeapon.sprite_node`, which points here.
extends Sprite2D
class_name WeaponVisual

## The equipped weapon instance this node draws. Assigned by WeaponHolder.
@export var weapon: BaseWeapon
