# The node that stands in for a held item in the scene tree.
#
# An item is a Resource, so it can never be a child itself - this is the one
# node per item that makes it visible, selectable and inspectable while the game
# runs. It carries no behaviour: the item's real work is done by the stat
# modifiers it applied to the holder and by the effect node
# (`Item.effect_scene`) that sits next to it under the ItemHolder.
#
# The node belongs to the ItemHolder, not to the item: item resources are shared
# between holders (each holder adds `load(path)`), so an item cannot hold a
# reference to "its" node.
extends Node
class_name ItemNode

## The held item this node represents. Assigned by ItemHolder.
@export var item: Item
