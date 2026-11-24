extends Node
class_name BossSpawner

@export var character: Character
## Optional arena reference. Auto-resolved from the "arena" group in _ready.
## When no arena exists (scenes without ground), spawns stay unclamped.
@export var arena: Arena
## Keep spawn points this far from the arena edge (boss body radius ~41px).
@export var arena_spawn_margin: float = 64.0
@export var spawn_active: bool = false
@export var boss_scene: PackedScene = preload("res://src/Systems/enemies/EnemyBoss.tscn")
@export var current_stage: int = 1
@export var health_growth_per_stage: float = 250
@export var damage_growth_per_stage: float = 1
## Extra stages' worth of scaling the final boss carries on top of the stage the
## player reached. The final boss is faced *instead* of another stage, so it has
## to sit above the stage that led to it - and it keeps climbing with
## `current_stage` if the player banked extra stages before taking the fight.
@export var final_boss_extra_stages: int = 2

## The boss loadout ramps once per stage and stops here. Two more shotguns a stage
## is already a lot by stage 4; letting it run on would leave a stage-10 boss
## holding twenty of them, which costs frames instead of adding threat. Four
## keeps the shipped ramp unchanged through stage 4 (6 shotguns, 2 pistols and
## the stage-4 `SpreadShot`), so only stages past that are affected.
const LOADOUT_STAGE_CAP: int = 4

## Seconds the teleport effect plays before the boss appears. 0 = instant.
@export var spawn_telegraph_time: float = SpawnPortal.DEFAULT_DURATION

var enemiesNode: Node = null
var boss_instance: Enemy = null
var _spawning := false


## True while the boss's teleport effect plays. The arena is empty then, so
## `StageManager` must not read that as the boss being dead.
func is_spawning() -> bool:
    return _spawning


func _ready():
    enemiesNode = get_node("../../Nodes/Enemies")
    if arena == null:
        arena = get_tree().get_first_node_in_group("arena") as Arena

func spawn_boss():
    _spawn_boss(current_stage)


## The final boss: the same encounter as the current stage's boss, scaled past
## it. `StageManager` calls this only from its final-boss phase.
func spawn_final_boss():
    _spawn_boss(current_stage + final_boss_extra_stages, true)


## Coins the boss of `stage` pays on death, from the `economy` config. The final
## boss pays nothing: the run ends there and no shop follows.
static func bounty_for(stage: int, is_final: bool) -> int:
    if is_final:
        return 0
    var economy := Wallet.config()
    return roundi(float(economy.get("boss_coins_base", 0)) + float(economy.get("boss_coins_per_stage", 0)) * (stage - 1))


## `stage` is the stage whose scaling this boss gets, which is `current_stage` for
## an ordinary boss and a few stages above it for the final one.
func _spawn_boss(stage: int, is_final: bool = false):
    if _spawning or (boss_instance and is_instance_valid(boss_instance)):
        return # already spawned (or teleporting in)

    var character_position: Vector2 = character.global_position
    var angle = randf_range(0, TAU)
    var radius = 700.0
    var spawn_position = clamp_spawn_position(character_position + Vector2(cos(angle), sin(angle)) * radius)

    if spawn_telegraph_time > 0.0:
        _spawning = true
        SpawnPortal.play(enemiesNode.get_parent(), spawn_position, spawn_telegraph_time, SpawnPortal.BOSS_RADIUS)
        await get_tree().create_timer(spawn_telegraph_time).timeout
        _spawning = false
        if not is_instance_valid(enemiesNode) or not enemiesNode.is_inside_tree():
            return

    boss_instance = boss_scene.instantiate()
    boss_instance.global_position = spawn_position
    enemiesNode.add_child(boss_instance)

    # The boss does not go through `SpawnerModifier` (no drops), so it pays its
    # bounty and leaves its corpse decal here.
    var bounty := bounty_for(stage, is_final)
    var health: Health = boss_instance.get_node_or_null("Health")
    if health and health.event_manager:
        health.event_manager.subscribe("on_death",
            func(event: Dictionary) -> void:
                if bounty > 0 and character:
                    Wallet.earn(character, Wallet.coins_for(character, bounty), "boss")
                DeathMark.leave_corpse(event.get("self")))

    # Apply stage-based scaling
    _apply_scaling(stage)

    if boss_instance.has_method("set_target_position"):
        boss_instance.set_target_position(character)
    
    print("Boss spawned!")

## Clamp a spawn point inside the arena (no-op when no arena is present).
func clamp_spawn_position(pos: Vector2) -> Vector2:
    if arena == null or not is_instance_valid(arena):
        return pos
    return arena.clamp_to_arena(pos, arena_spawn_margin)

## `stage` is the stage this boss is scaled as, not necessarily `current_stage`:
## `spawn_final_boss()` passes a few stages beyond it.
func _apply_scaling(stage: int) -> void:
    var stats = boss_instance.get_node_or_null("Stats")
    if not stats:
        return
    # Scale only by phase
    var extra_health = health_growth_per_stage * stage
    var extra_damage = damage_growth_per_stage * stage
    stats.set_base_stat("health", stats.stats["health"] + extra_health)
    stats.set_base_stat("damage", stats.stats["damage"] + extra_damage)
    
    #boss_instance.item_holder.add_item(load("res://src/Resources/items/HealthMeat.tres"))
    # Clamped: the weapon ramp stops at `LOADOUT_STAGE_CAP` so a boss scaled past
    # the normal run carries a budgeted loadout rather than another pair of
    # shotguns per stage. Below the cap this is the shipped ramp, unchanged.
    var loadout_stage: int = mini(stage, LOADOUT_STAGE_CAP)
    for i in loadout_stage:
        boss_instance.weapon_holder.add_weapon(load("res://src/Resources/weapons/boss/BossShotgun.tres"))
        boss_instance.weapon_holder.add_weapon(load("res://src/Resources/weapons/boss/BossShotgun.tres"))
        if i == 2:
            boss_instance.weapon_holder.add_weapon(load("res://src/Resources/weapons/Pistol.tres"))
            boss_instance.weapon_holder.add_weapon(load("res://src/Resources/weapons/Pistol.tres"))
        if i == 3:
            boss_instance.item_holder.add_item(load("res://src/Resources/items/SpreadShot.tres"))

    boss_instance.health_node.heal(1000000)
