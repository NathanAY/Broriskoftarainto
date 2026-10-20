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
