extends Resource
class_name CharacterData

# Display name for UI
@export var display_name: String = "Unnamed"
@export var description: String = ""

# Optional base stats to set when this character is selected. Overrides defaults in Stats.gd. Should be a dictionary matching Stats.add_modifier format, e.g. {"health": {"flat": 20}, "attack_speed": {"percent": 0.1}}
#
# This is the archetype's own stat block: the values that differ from the
# default Stats (health 95, damage 0.9, movement_speed 0.35...). It is NOT the
# place for stats that need a modifier to do anything - a stat alone is inert
# without the behavior that reads it (see `modifiers`).
@export var base_stats: Dictionary = {}

# Everything that changes this character, as a flat list of two entry kinds
# applied in order by CharacterInitializer:
#
#   Dictionary  - a value. Passed to Stats.add_modifier as-is, e.g.
#                 {"armor": {"flat": 4}} or {"attack_speed": {"percent": 0.2}}
#   PackedScene - a behavior. A modifier scene (Systems/Items/modifiers/*.tscn)
#                 instantiated and wired to the character, e.g.
#                 ArmorModifier.tscn.
#
# A stat that only exists as a number has no effect: `armor` becomes damage
# reduction only while an ArmorModifier is listening. So an armored character
# lists BOTH, in this one list:
#
#   modifiers = [{"armor": {"flat": 4}}, <ArmorModifier.tscn>]
#
# This is the only correct way to give a character armor (or any other
# stat-driven behavior) - never a bare `armor` key in `base_stats`. Adding a
# brand new behavior to a character needs no code: drop that modifier's scene
# into this list.
@export var modifiers: Array = []

# Starting items for the character
@export var starting_items: Array[Item] = []

# Starting weapons equipped on spawn (e.g. Fist for the Brawler)
@export var starting_weapons: Array[BaseWeapon] = []

@export var small_icon: Texture2D    # assign in .tres
@export var sprite: Texture2D    # assign in .tres
