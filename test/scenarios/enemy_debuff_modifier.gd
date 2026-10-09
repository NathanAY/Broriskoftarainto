extends Node
class_name EnemyDebuffModifier

## Dev-only: gives every enemy the spawner fields one item, so a debuff can land
## on the player during a normal-looking run.
##
## `Enemy.gd` carries no items in the shipped game, which means the player's
## debuff row (`src/ui/buff_ui.gd`) is correct code over an empty world: nothing
## ever spawns a `Debuff` on the player. This is the seam that makes the row
## reachable without touching the live enemy path - and without giving every
## enemy a debuff item in a real run, which would be a balance change and
## `docs/systems/balance.md` governs that.
##
## It plugs into `EnemySpawner`'s own extension point: the spawner calls
## `attach_to_enemy()` on each child that has it, right before the enemy enters
## the tree. See `docs/systems/debug_scenarios.md`.

## Full `res://` path of an item under `src/Resources/items`.
@export var item_path: String = ""
## 0..1, per enemy. Below 1.0 only some enemies carry it, which is what a real
## elite would look like and keeps the debuff row from filling instantly.
@export_range(0.0, 1.0, 0.05) var chance: float = 1.0

var rng := RandomNumberGenerator.new()


func _ready() -> void:
    # Seeded from the instance id rather than left at the default: the same
    # scenario must not hand every enemy the item, but two runs of the same
    # scenario should also not be identical.
    rng.seed = hash(name) + get_instance_id()


## Called by `EnemySpawner` once per spawned enemy, before the enemy is added to
## the tree. `ItemHolder.hold_owner` is a getter, so the item wires itself up off
## tree and only has to run `_ready()` when the enemy joins.
func attach_to_enemy(enemy: Node, _character: Character) -> void:
    if item_path.is_empty() or not ResourceLoader.exists(item_path):
        push_warning("EnemyDebuffModifier: no such item: %s" % item_path)
        return
    if rng.randf() > chance:
        return
    var item: Item = load(item_path)
    var item_holder: ItemHolder = enemy.get_node_or_null("ItemHolder")
    if item_holder == null:
        push_warning("EnemyDebuffModifier: enemy has no ItemHolder")
        return
    item_holder.add_item(item)
