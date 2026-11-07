# One row of the spawner's enemy table: which scene to spawn, how likely it is
# to come up, and the loop it unlocks on.
#
# A Resource rather than two parallel exported arrays, because the inspector
# cannot check that two arrays are the same length, and a row of
# hand-synchronised parallel arrays rots the first time someone adds a row.
class_name EnemySpawnEntry
extends Resource

## The enemy scene this row spawns.
@export var scene: PackedScene

## How likely this row is to come up, relative to the other open rows. 1.0 is
## an ordinary share; 3.0 is three times as likely as a 1.0 row.
@export var weight: float = 1.0

## Loop the entry unlocks on. 1 = from the first wave.
@export_range(1, 3) var min_loop: int = 1

## How many copies of this scene one draw spawns. A pack enemy arrives as a
## group; an ordinary enemy is a pack of one.
@export_range(1, 12) var pack_size: int = 1

## Loop the row turns elite on. 0 = never. An elite is the same scene with its
## health and damage multiplied and its sprite tinted, not a separate type.
@export_range(0, 3) var elite_min_loop: int = 0

## Multiplies an elite's base health.
@export var elite_health_multiplier: float = 1.5

## Multiplies an elite's base damage.
@export var elite_damage_multiplier: float = 1.3

## Tint applied to an elite's visual container. It sits on `Node2D`, not the
## `Sprite2D`, because `HitFlashManager` tweens the sprite's own modulate and
## resets it to white on every hit.
@export var elite_tint: Color = Color(1.4, 1.15, 1.15)
