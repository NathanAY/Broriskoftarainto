extends Resource
class_name CharacterData

# Display name for UI
@export var display_name: String = "Unnamed"
@export var description: String = ""

# Optional base stats to set when this character is selected. Overrides defaults in Stats.gd. Should be a dictionary matching Stats.add_modifier format, e.g. {"health": {"flat": 20}, "attack_speed": {"percent": 0.1}}
@export var base_stats: Dictionary = {}

# Optional modifiers applied on top of base stats.
# Each entry should be a dictionary matching Stats.add_modifier format,
# e.g. {"attack_speed": {"percent": 0.2}, "condition": { ... }}
@export var modifiers: Array = []
