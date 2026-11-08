extends Node
class_name BossSpawner

@export var character: Character
## Optional arena reference. Auto-resolved from the "arena" group in _ready.
## When no arena exists (scenes without ground), spawns stay unclamped.
@export var arena: Arena
## Keep spawn points this far from the arena edge (boss body radius ~41px).
@export var arena_spawn_margin: float = 64.0
@export var spawn_active: bool = false
@export var boss_scene: PackedScene = preload("res://src/Systems/EnemyBoss.tscn")
@export var current_loop: int = 1
@export var health_growth_per_loop: float = 250
@export var damage_growth_per_loop: float = 1
## Extra loops' worth of scaling the final boss carries on top of the loop the
## player reached. The final boss is faced *instead* of another loop, so it has
## to sit above the loop that led to it - and it keeps climbing with
## `current_loop` if the player banked extra loops before taking the fight.
@export var final_boss_extra_loops: int = 2

## The boss loadout ramps once per loop and stops here. Two more shotguns a loop
## is already a lot by loop 4; letting it run on would leave a loop-10 boss
## holding twenty of them, which costs frames instead of adding threat. Four
## keeps the shipped ramp unchanged through loop 4 (6 shotguns, 2 pistols and
## the loop-4 `SpreadShot`), so only loops past that are affected.
const LOADOUT_LOOP_CAP: int = 4

var enemiesNode: Node = null
var boss_instance: Enemy = null

func _ready():
    enemiesNode = get_node("../../Nodes/Enemies")
    if arena == null:
        arena = get_tree().get_first_node_in_group("arena") as Arena

func spawn_boss():
    _spawn_boss(current_loop)


## The final boss: the same encounter as the current loop's boss, scaled past
## it. `StageManager` calls this only from its final-boss stage.
func spawn_final_boss():
    _spawn_boss(current_loop + final_boss_extra_loops)


## `loop` is the loop whose scaling this boss gets, which is `current_loop` for
## an ordinary boss and a few loops above it for the final one.
func _spawn_boss(loop: int):
    if boss_instance and is_instance_valid(boss_instance):
        return # already spawned

    boss_instance = boss_scene.instantiate()
    var character_position: Vector2 = character.global_position
    var angle = randf_range(0, TAU)
    var radius = 700.0
    var spawn_position = clamp_spawn_position(character_position + Vector2(cos(angle), sin(angle)) * radius)
    boss_instance.global_position = spawn_position
    
    enemiesNode.add_child(boss_instance)

    # Apply loop-based scaling
    _apply_scaling(loop)

    if boss_instance.has_method("set_target_position"):
        boss_instance.set_target_position(character)
    
    print("Boss spawned!")

## Clamp a spawn point inside the arena (no-op when no arena is present).
func clamp_spawn_position(pos: Vector2) -> Vector2:
    if arena == null or not is_instance_valid(arena):
        return pos
    return arena.clamp_to_arena(pos, arena_spawn_margin)

## `loop` is the loop this boss is scaled as, not necessarily `current_loop`:
## `spawn_final_boss()` passes a few loops beyond it.
func _apply_scaling(loop: int) -> void:
    var stats = boss_instance.get_node_or_null("Stats")
    if not stats:
        return
    # Scale only by stage
    var extra_health = health_growth_per_loop * loop
    var extra_damage = damage_growth_per_loop * loop
    stats.set_base_stat("health", stats.stats["health"] + extra_health)
    stats.set_base_stat("damage", stats.stats["damage"] + extra_damage)
    
    #boss_instance.item_holder.add_item(load("res://src/Resources/items/HealthMeat.tres"))
    # Clamped: the weapon ramp stops at `LOADOUT_LOOP_CAP` so a boss scaled past
    # the normal run carries a budgeted loadout rather than another pair of
    # shotguns per loop. Below the cap this is the shipped ramp, unchanged.
    var loadout_loop: int = mini(loop, LOADOUT_LOOP_CAP)
    for i in loadout_loop:
        boss_instance.weapon_holder.add_weapon(load("res://src/Resources/weapons/boss/BossShotgun.tres"))
        boss_instance.weapon_holder.add_weapon(load("res://src/Resources/weapons/boss/BossShotgun.tres"))
        if i == 2:
            boss_instance.weapon_holder.add_weapon(load("res://src/Resources/weapons/Pistol.tres"))
            boss_instance.weapon_holder.add_weapon(load("res://src/Resources/weapons/Pistol.tres"))
        if i == 3:
            boss_instance.item_holder.add_item(load("res://src/Resources/items/SpreadShot.tres"))

    boss_instance.health_node.heal(1000000)
