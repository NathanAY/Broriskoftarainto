## The final boss's mind: its phases, which attack comes next, and how it moves
## between attacks. It sits on the boss as its `MovementBehaviour`, so `Enemy`
## calls `process_movement()` every physics frame and nothing else drives it.
##
## Attacks are the `BossAttack` children of this node. One runs at a time; the
## brain picks the next by weight among those allowed in the current phase,
## never the same one twice in a row, and waits `attack_gap` in between.
##
## Phases change at the health fractions in `phase_thresholds`. A change is a
## set piece: the running attack is cut, the boss stands still and takes no
## damage for `transition_time`. A hit that would carry the boss past the next
## threshold is cut short at it, so a burst build cannot skip a phase.
## Entering phase 3 removes the front shield, swaps in the broken art and makes
## the boss take `phase3_damage_taken_mult` more damage. Every phase change
## starts with a shockwave that knocks the player back (a reset, no damage).
##
## In the `adds_phases` the brain also spawns Debt Collectors (`add_scene`, a
## pack every `adds_interval`, capped at `adds_max_alive`). They die when their
## phase ends and when the boss dies, so they never hold the final phase open.
## See `docs/systems/final_boss.md`.
extends MovementBehaviour
class_name BossBrain

signal phase_changed(phase: int)

const LAST_PHASE := 3

## The art shown from phase 3 on (vault burst open, plate cracked).
@export var broken_texture: Texture2D
## The Debt Collectors the boss calls in.
@export var add_scene: PackedScene = preload("res://src/Systems/enemies/EnemySwarmer.tscn")
## Tint on the adds' `Node2D` container, so they read as the boss's.
@export var add_tint: Color = Color(1.0, 0.85, 0.4)
## Tint on the boss once it enrages.
@export var enrage_tint: Color = Color(1.0, 0.55, 0.5)
## The name card and boss bar text.
@export var boss_name: String = "THE VAULT BARON"
@export var boss_epithet: String = "Chairman of the Wastes"
## Played at each phase change and at the kill.
@export var phase_sound: AudioStream
@export var death_sound: AudioStream

var phase: int = 1
var current_attack: BossAttack = null
var last_attack: BossAttack = null
var rng := RandomNumberGenerator.new()
## The adds alive right now. Read by the tests.
var adds: Array[Enemy] = []
## Seconds the fight has run, and whether it ran past `enrage_time`.
var fight_time: float = 0.0
var enraged: bool = false
## The boss bar and name card. Null until `_ready`.
var hud: BossHud = null

var _adds_left: float = 0.0
var _transition_left: float = 0.0
var _gap_left: float = 0.0
var _speed_boost: Dictionary = {}
var _dead: bool = false


static func config() -> Dictionary:
    return GameConfig.section("final_boss")


func _ready() -> void:
    rng.randomize()
    _gap_left = float(config().get("intro_time", 1.5))
    var bus := _bus()
    if bus == null:
        return
    bus.subscribe("before_take_damage", Callable(self, "_on_before_take_damage"), Damage.PHASE_MITIGATE)
    bus.subscribe("after_take_damage", Callable(self, "_on_after_take_damage"))
    bus.subscribe("on_death", Callable(self, "_on_death"))
    # The HUD goes on the boss once the boss is ready: it is still adding its own
    # children now, and the name card tween needs the HUD inside the tree. A
    # deferred call instead leaked the HUD when the boss was freed first.
    var boss := get_parent() as Enemy
    if boss != null:
        boss.ready.connect(_build_hud.bind(boss), CONNECT_ONE_SHOT)


func attacks() -> Array[BossAttack]:
    var found: Array[BossAttack] = []
    for child in get_children():
        if child is BossAttack:
            found.append(child)
    return found


func is_transitioning() -> bool:
    return _transition_left > 0.0


func process_movement(creature_self: CharacterBody2D, delta: float) -> void:
    var boss := creature_self as Enemy
    if _dead or boss == null:
        return
    fight_time += delta
    if not enraged and fight_time >= float(config().get("enrage_time", 150.0)):
        _enrage(boss)
    if is_transitioning():
        boss.velocity = Vector2.ZERO
        boss.anim_player.play("idle")
        _transition_left -= delta
        if _transition_left <= 0.0:
            _enter_phase(phase + 1)
        return
    _adds_tick(boss, delta)
    if current_attack != null:
        if current_attack.tick(delta):
            last_attack = current_attack
            current_attack = null
            _gap_left = float(config().get("attack_gap", 0.8)) * recover_mult()
        return
    _move(boss)
    _gap_left -= delta
    if _gap_left <= 0.0 and boss.target != null:
        current_attack = pick_attack()
        if current_attack != null:
            current_attack.start(boss, boss.target)


## A weighted pick among the attacks allowed in this phase, leaving out the
## last one whenever anything else is allowed.
func pick_attack() -> BossAttack:
    var pool: Array[BossAttack] = []
    for attack in attacks():
        if attack.allowed_in(phase) and attack.weight() > 0.0:
            pool.append(attack)
    if pool.size() > 1:
        pool.erase(last_attack)
    if pool.is_empty():
        return null
    var total := 0.0
    for attack in pool:
        total += attack.weight()
    var roll := rng.randf() * total
    for attack in pool:
        roll -= attack.weight()
        if roll <= 0.0:
            return attack
    return pool.back()


## Between attacks: walk to `keep_distance` from the target and hold there.
func _move(boss: Enemy) -> void:
    var target := boss.target as Node2D
    if target == null:
        boss.velocity = Vector2.ZERO
        return
    var to_target := target.global_position - boss.global_position
    var keep := float(_per_phase("keep_distance", 0.0))
    if to_target.length() > keep:
        var direction := to_target.normalized()
        boss.velocity = direction * boss.stats.get_movement_speed_px()
        boss.anim_player.play("move")
        boss.sprite.flip_h = direction.x < 0
    else:
        boss.velocity = Vector2.ZERO
        boss.anim_player.play("idle")


func _enter_phase(next: int) -> void:
    _transition_left = 0.0
    phase = next
    _gap_left = float(config().get("attack_gap", 0.8))
    var boss := get_parent() as Enemy
    if boss != null:
        _apply_speed(boss)
        if phase == LAST_PHASE:
            _break_open(boss)
        if _adds_allowed():
            # A phase with adds opens with a pack, then they arrive on the clock.
            _spawn_adds(boss)
            _adds_left = float(config().get("adds_interval", 12.0))
        else:
            kill_adds()
    phase_changed.emit(phase)
    _check_threshold()


func _start_transition() -> void:
    if current_attack != null:
        current_attack.stop()
        last_attack = current_attack
        current_attack = null
    _transition_left = float(config().get("transition_time", 2.0))
    var boss := get_parent() as Enemy
    if boss != null:
        shockwave(boss)
        BossBullets.shake(boss, "phase")
        BossBullets.sound(phase_sound, boss.global_position)


## Knocks the target out to `shockwave_radius` if it is inside it. No damage:
## it is a reset, so a phase change never starts with the player on the boss.
func shockwave(boss: Enemy) -> void:
    var radius := float(config().get("shockwave_radius", 400.0))
    var ring := GroundMarker.new()
    ring.color = Color(1.0, 0.85, 0.4, 0.0)
    ring.outline_color = Color(1.0, 0.85, 0.4, 0.9)
    ring.outline_width = 10.0
    ring.radius = 0.0
    BossBullets.world(boss).add_child(ring)
    ring.global_position = boss.global_position
    var tween := ring.create_tween()
    tween.tween_property(ring, "radius", radius, 0.35)
    tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.35)
    tween.tween_callback(ring.queue_free)

    var target := boss.target as Node2D
    if target == null or not is_instance_valid(target):
        return
    var away := target.global_position - boss.global_position
    if away.length() > radius:
        return
    if away.length() < 0.001:
        away = Vector2.RIGHT
    var knock := target.get_node_or_null("KnockbackController") as KnockbackController
    if knock == null:
        knock = KnockbackController.new()
        knock.name = "KnockbackController"
        target.add_child(knock)
    knock.start_knockback(away.normalized() * float(config().get("shockwave_force", 6.0)),
            float(config().get("shockwave_duration", 0.6)))


func _adds_allowed() -> bool:
    for p in config().get("adds_phases", [2]):
        if int(p) == phase:
            return true
    return false


func _adds_tick(boss: Enemy, delta: float) -> void:
    if not _adds_allowed():
        return
    _adds_left -= delta
    if _adds_left <= 0.0:
        _spawn_adds(boss)
        _adds_left = float(config().get("adds_interval", 12.0))


## A pack of adds in a ring around the target, up to `adds_max_alive`.
func _spawn_adds(boss: Enemy) -> void:
    adds.assign(adds.filter(func(a): return is_instance_valid(a) and not a.health_node.is_dead))
    var room := int(config().get("adds_max_alive", 10)) - adds.size()
    var count := mini(int(config().get("adds_pack_size", 5)), room)
    var target := boss.target as Node2D
    if count <= 0 or add_scene == null or target == null or boss.get_parent() == null:
        return
    var distance := float(config().get("adds_spawn_distance", 450.0))
    for i in count:
        var add: Enemy = add_scene.instantiate()
        var at := target.global_position + Vector2.from_angle(rng.randf() * TAU) * distance
        add.global_position = BossBullets.clamp_to_arena(boss, at, 64.0)
        boss.get_parent().add_child(add)
        add.visual.modulate = add_tint
        add.set_target_position(target)
        adds.append(add)


## Kills every add the boss called in. They play their death like any enemy.
func kill_adds() -> void:
    for add in adds:
        if is_instance_valid(add) and not add.health_node.is_dead:
            add.health_node.die(DamageContext.new())
    adds.clear()


## The health fraction that ends the current phase, or -1 in the last one.
func _next_threshold() -> float:
    var thresholds: Array = config().get("phase_thresholds", [0.65, 0.30])
    if phase - 1 < thresholds.size():
        return float(thresholds[phase - 1])
    return -1.0


func _check_threshold() -> void:
    var health := _health()
    if health == null or health.is_dead or is_transitioning():
        return
    var threshold := _next_threshold()
    if threshold >= 0.0 and health.current_health <= health.max_health * threshold:
        _start_transition()


func _on_before_take_damage(event: Dictionary) -> void:
    var ctx := event.get("damage_context") as DamageContext
    var health := _health()
    if ctx == null or health == null:
        return
    if is_transitioning() or (current_attack != null and current_attack.blocks_damage()):
        ctx.final_amount = 0.0
        return
    if phase == LAST_PHASE:
        ctx.final_amount *= float(config().get("phase3_damage_taken_mult", 1.0))
        return
    # Cut the hit short at the threshold so the next phase is always played.
    var floor_health := health.max_health * _next_threshold()
    ctx.final_amount = minf(ctx.final_amount, maxf(health.current_health - floor_health, 0.0))


func _on_after_take_damage(_event: Dictionary) -> void:
    _check_threshold()


func _on_death(_event: Dictionary) -> void:
    _dead = true
    if current_attack != null:
        current_attack.stop()
        current_attack = null
    kill_adds()
    _death_sequence(get_parent() as Enemy)


## Phase speed as a `Stats` modifier, replacing the previous phase's.
func _apply_speed(boss: Enemy) -> void:
    if not _speed_boost.is_empty():
        boss.stats.remove_modifier(_speed_boost)
    _speed_boost = {"movement_speed": {"percent": float(_per_phase("speed_mult", 1.0)) - 1.0}}
    boss.stats.add_modifier(_speed_boost)


func _break_open(boss: Enemy) -> void:
    var shield := boss.get_node_or_null("FrontShield") as FrontShield
    if shield != null:
        _bus().unsubscribe("before_take_damage", Callable(shield, "_on_before_take_damage"))
        shield.queue_free()
    if broken_texture != null:
        boss.sprite.texture = broken_texture
    # The ram plate pops off: a blast visual at the front, no damage.
    var front := Vector2.LEFT if boss.sprite.flip_h else Vector2.RIGHT
    BossBullets.burst_visual(boss, boss.global_position + front * boss.body_radius(),
            float(config().get("plate_burst_radius", 70.0)))


## `key` is a per-phase list in the config; this phase's entry.
func _per_phase(key: String, fallback: float) -> float:
    var values: Array = config().get(key, [])
    if values.is_empty():
        return fallback
    return float(values[mini(phase, values.size()) - 1])


func _bus() -> EventManager:
    if get_parent() == null:
        return null
    return get_parent().get_node_or_null("EventManager") as EventManager


func _health() -> Health:
    if get_parent() == null:
        return null
    return get_parent().get_node_or_null("Health") as Health


## Past `enrage_time` the boss turns red and recovers faster (`enrage_recover_mult`
## on every recovery and attack gap), so a stalled fight still ends.
func _enrage(boss: Enemy) -> void:
    enraged = true
    if hud != null:
        hud.set_enraged(true)
    if current_attack == null or not current_attack.is_running():
        boss.visual.modulate = rest_tint()


func recover_mult() -> float:
    return float(config().get("enrage_recover_mult", 0.5)) if enraged else 1.0


func rest_tint() -> Color:
    return enrage_tint if enraged else Color.WHITE


## The kill: time slows to `death_time_scale` for `death_slowmo_time` real
## seconds, then eases back over `death_ramp_time`, while a fountain of coins
## bursts out of the body. The time tween is owned by the tree and animates the
## `Engine` singleton, so it still restores time after this node is freed; it
## ignores time scale and pause so the win screen cannot freeze it half-way.
func _death_sequence(boss: Enemy) -> void:
    if boss == null or not boss.is_inside_tree():
        return
    var cfg := config()
    BossBullets.shake(boss, "death")
    BossBullets.sound(death_sound, boss.global_position)
    Engine.time_scale = float(cfg.get("death_time_scale", 0.3))
    var restore := get_tree().create_tween()
    restore.set_ignore_time_scale(true)
    restore.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    restore.tween_interval(float(cfg.get("death_slowmo_time", 1.0)))
    restore.tween_property(Engine, "time_scale", 1.0, float(cfg.get("death_ramp_time", 0.5)))

    var fountain := CPUParticles2D.new()
    fountain.texture = BossBullets.COIN_TEXTURE
    fountain.amount = int(cfg.get("death_coins", 80))
    fountain.one_shot = true
    fountain.explosiveness = 1.0
    fountain.lifetime = float(cfg.get("death_coin_lifetime", 1.6))
    fountain.direction = Vector2.UP
    fountain.spread = 70.0
    fountain.gravity = Vector2(0, 900)
    fountain.initial_velocity_min = 300.0
    fountain.initial_velocity_max = 650.0
    fountain.angular_velocity_min = -360.0
    fountain.angular_velocity_max = 360.0
    var coin_scale := float(cfg.get("coin_size", 28.0)) / BossBullets.COIN_TEXTURE.get_width()
    fountain.scale_amount_min = coin_scale * 0.8
    fountain.scale_amount_max = coin_scale * 1.2
    fountain.finished.connect(fountain.queue_free)
    BossBullets.world(boss).add_child(fountain)
    fountain.global_position = boss.global_position
    fountain.emitting = true


func _build_hud(boss: Enemy) -> void:
    hud = BossHud.new()
    boss.add_child(hud)
    hud.setup(boss, boss_name, boss_epithet, config().get("phase_thresholds", [0.65, 0.30]),
            float(config().get("name_card_time", 2.5)))


## Debug seam: takes the boss straight into `target_phase` the way the fight
## would - health set to each threshold, then that phase entered (speed, adds,
## shield break, art) - but with no transition, so no wait and no shockwave.
## Used by the final-boss debug scenario.
func skip_to_phase(target_phase: int) -> void:
    var health := _health()
    if health == null or health.is_dead:
        return
    while phase < mini(target_phase, LAST_PHASE):
        if current_attack != null:
            current_attack.stop()
            current_attack = null
        var threshold := _next_threshold()
        if threshold >= 0.0:
            health.current_health = minf(health.current_health, health.max_health * threshold)
        _enter_phase(phase + 1)
    # The bar listens to `on_health_changed`; a zero heal emits it.
    health.heal(0.0)
