extends Node
class_name EnemySpawner

@export var character: Character
## Optional arena reference. Auto-resolved from the "arena" group in _ready.
## When no arena exists (scenes without ground), spawns stay unclamped.
@export var arena: Arena
## Keep spawn points this far from the arena edge (enemy body radius ~41px).
@export var arena_spawn_margin: float = 64.0
@export var spawn_interval = 1 # base seconds between spawn ticks at target population
@export var min_spawn_wait: float = 0.4 # fastest tick when arena is empty (strong builds stay in danger)
@export var max_spawn_wait: float = 4.0 # slowest tick when overpopulated (never boring, caps old 30s bug)
@export var max_alive_enemies: int = 100 # perf + weak-build protection: skip ticks above this
@export var health_growth_per_loop: float = 20
@export var damage_growth_per_loop: float = 1
@export var base_target_enemy_count = 5 # initial target enemies per stage
@export var current_loop: int = 1
@export var spawn_active: bool = true

# Group spawning parameters
@export var group_size = 3  # number of enemies to spawn per group
@export var group_spawn_radius = 120.0  # radius within which group members spawn around center
@export var group_spawn_interval = 0.15  # delay between spawning enemies within a group
@export var min_groups_per_spawn = 1  # minimum number of groups to spawn at once
@export var max_groups_per_spawn = 2  # maximum number of groups to spawn at once (randomized)
@export var use_group_spawning = true  # toggle between single spawn and group spawn mode
## Keep spawned enemies at least this far apart from each other (any two alive
## enemies at spawn time). Enemy body diameter is ~82 (radius 41), so 90 leaves
## a small gap instead of spawning buddies that immediately shove each other.
@export var min_spawn_separation: float = 90.0
## How many candidate spots to try before falling back to the last candidate,
## so spawning never deadlocks when a packed arena wall forces overlaps.
@export var max_spawn_attempts: int = 12

var enemy_scene = preload("res://src/Systems/Enemy.tscn")
var enemiesNode: Node = null
var modifiers: Array = []
var target_enemy_count: int
var spawn_timer: Timer = null

func _ready():
    spawn_timer = Timer.new()
    spawn_timer.wait_time = spawn_interval
    spawn_timer.one_shot = false
    spawn_timer.timeout.connect(_on_spawn_timer_timeout)
    add_child(spawn_timer)
    spawn_timer.start()
    enemiesNode = get_node("../../Nodes/Enemies")
    target_enemy_count = base_target_enemy_count
    if arena == null:
        arena = get_tree().get_first_node_in_group("arena") as Arena
    for c in get_children():
        if c.has_method("attach_to_enemy"):
            modifiers.append(c)

func _on_spawn_timer_timeout():
    if spawn_active:
        var current_enemies := 0
        if enemiesNode != null:
            current_enemies = enemiesNode.get_child_count()
        if current_enemies >= max_alive_enemies:
            # Over cap: skip this tick to save perf / protect weak builds.
            spawn_timer.wait_time = max_spawn_wait
            spawn_timer.start()
            return
        if use_group_spawning:
            spawn_enemy_group()
        else:
            spawn_enemy()
        _adjust_spawn_rate()
    else:
        # Stop spawning after stage time
        spawn_timer.stop()

## Watchdog: if the player clears the arena mid-tick, shorten a long pending
## wait so empty-arena downtime never exceeds the loop-scaled refill delay.
func _process(_delta: float) -> void:
    if not spawn_active:
        return
    if enemiesNode == null or spawn_timer == null:
        return
    if spawn_timer.is_stopped():
        return
    if enemiesNode.get_child_count() == 0:
        var refill := get_empty_refill_delay()
        if spawn_timer.time_left > refill:
            spawn_timer.wait_time = refill
            spawn_timer.start()

func spawn_enemy_group():
    if not character:
        return

    var groups_to_spawn = randi_range(min_groups_per_spawn, max_groups_per_spawn)
    for i in range(groups_to_spawn):
        # Choose a center point for this group
        var character_position: Vector2 = character.global_position
        var group_center_angle = randf_range(0, TAU)
        var group_center_radius = 500.0
        var group_center = clamp_spawn_position(character_position + Vector2(cos(group_center_angle), sin(group_center_angle)) * group_center_radius)

        # Spawn enemies within the group
        var reserved: Array = [group_center]
        for j in range(group_size):
            # Use a timer to stagger spawns within the group
            var enemy = enemy_scene.instantiate()
            var spawn_position = _pick_spawn_position(func() -> Vector2:
                var angle = randf_range(0, TAU)
                var radius = randf_range(0, group_spawn_radius)
                return group_center + Vector2(cos(angle), sin(angle)) * radius
            , reserved)
            reserved.append(spawn_position)
            enemy.global_position = spawn_position

            # Apply modifiers
            for mod in modifiers:
                mod.attach_to_enemy(enemy, character)

            # Apply stage-based scaling
            _apply_stage_scaling(enemy)

            enemiesNode.add_child(enemy)
            enemy.set_target_position(character)

            # Stagger spawning within the group
            if j < group_size - 1:
                await get_tree().create_timer(group_spawn_interval).timeout

func spawn_enemy():
    if not character:
        return

    var enemy = enemy_scene.instantiate()
    var character_position: Vector2 = character.global_position
    var spawn_position = _pick_spawn_position(func() -> Vector2:
        var angle = randf_range(0, TAU)
        return character_position + Vector2(cos(angle), sin(angle)) * 500.0
    , [])
    enemy.global_position = spawn_position

    # Apply modifiers
    for mod in modifiers:
        mod.attach_to_enemy(enemy, character)

    # Apply stage-based scaling
    _apply_stage_scaling(enemy)

    enemiesNode.add_child(enemy)
    enemy.set_target_position(character)

## Clamp a spawn point inside the arena (no-op when no arena is present,
## so scenes without ground keep the old ring-around-character behavior).
func clamp_spawn_position(pos: Vector2) -> Vector2:
    if arena == null or not is_instance_valid(arena):
        return pos
    return arena.clamp_to_arena(pos, arena_spawn_margin)

## Ask `candidate` for spots until one keeps `min_spawn_separation` from every
## alive enemy and every reserved point of the current spawn batch. Falls back
## to the last candidate after `max_spawn_attempts` so a packed arena wall can
## never make a spawn silently drop. Candidates are clamped to the arena.
func _pick_spawn_position(candidate: Callable, reserved: Array) -> Vector2:
    var chosen: Vector2 = clamp_spawn_position(candidate.call())
    for attempt in max_spawn_attempts:
        chosen = clamp_spawn_position(candidate.call())
        if not _is_too_close_to_any(chosen, reserved):
            return chosen
    return chosen

func _is_too_close_to_any(pos: Vector2, reserved: Array) -> bool:
    var min_dist_sq := min_spawn_separation * min_spawn_separation
    for other in reserved:
        if pos.distance_squared_to(other) < min_dist_sq:
            return true
    if enemiesNode != null:
        for enemy in enemiesNode.get_children():
            if enemy is Node2D:
                if pos.distance_squared_to((enemy as Node2D).global_position) < min_dist_sq:
                    return true
    return false


func _apply_stage_scaling(enemy: Node) -> void:
    var stats = enemy.get_node_or_null("Stats")
    if not stats:
        return
    # Scale only by stage
    var extra_health = health_growth_per_loop * (current_loop - 1)
    var extra_damage = damage_growth_per_loop * (current_loop - 1)
    stats.set_base_stat("health", stats.stats["health"] + extra_health)
    stats.set_base_stat("damage", stats.stats["damage"] + extra_damage)

func _adjust_spawn_rate():
    var current_enemies = enemiesNode.get_child_count()
    if current_enemies == 0:
        # Empty arena: loop-scaled fast refill (later Loops refill faster).
        spawn_timer.wait_time = get_empty_refill_delay()
        spawn_timer.start()
        return
    var multiplier = 1.0
    if current_enemies < target_enemy_count:
        multiplier = 1.0 + float(target_enemy_count - current_enemies)
    elif current_enemies > target_enemy_count:
        multiplier = max(0.1, float(target_enemy_count) / current_enemies)
    spawn_timer.wait_time = clampf(spawn_interval / multiplier, min_spawn_wait, max_spawn_wait)
    spawn_timer.start()

## Loop-scaled empty-arena refill: L1=1.0s, L2=0.85s, L3=0.7s, ... floor 0.3s.
func get_empty_refill_delay() -> float:
    return maxf(0.3, 1.0 - 0.15 * float(current_loop - 1))

## Wave entry point: (re)starts the cadence so a fresh Wave never inherits a
## stale long wait or a stopped timer. First tick lands ~spawn_interval (1s).
func start_wave() -> void:
    spawn_active = true
    target_enemy_count = base_target_enemy_count + current_loop - 1
    if spawn_timer == null:
        return
    spawn_timer.wait_time = float(spawn_interval)
    spawn_timer.start()

func _on_next_stage():
    current_loop += 1
    start_wave()
    print("Stage %d started! Target enemies: %d" % [current_loop, target_enemy_count])
