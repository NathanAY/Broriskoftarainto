## One attack of the final boss. `BossBrain` picks it, calls `start()`, then
## `tick()` once per physics frame until `tick()` returns true.
##
## Every attack runs the same timeline, which is the fight's fairness rule:
## TELEGRAPH (the boss stands still and glows) -> ACTIVE (the attack itself) ->
## RECOVER (the boss stands still: the player's damage window).
## A subclass overrides only the hooks it needs. Its numbers live in
## `game_config.json` under `final_boss.attacks.<config_key>`.
extends Node
class_name BossAttack

enum Step { TELEGRAPH, ACTIVE, RECOVER, DONE }

## The key of this attack's block under `final_boss.attacks`.
@export var config_key: String = ""
## Colour the boss pulses to while the attack telegraphs.
@export var telegraph_color: Color = Color(1.0, 0.85, 0.3)
## Played when the warning starts, when the attack goes off, and on whatever the
## attack calls an impact (a safe landing, a wall hit, an eruption).
@export var telegraph_sound: AudioStream
@export var active_sound: AudioStream
@export var impact_sound: AudioStream

var boss: Enemy = null
var target: Node2D = null
var step: int = Step.DONE

var _time: float = 0.0
## Extra recovery an attack can add (the ram after a wall hit).
var _extra_recover: float = 0.0
var _pulse: Tween = null


## This attack's config block.
func cfg() -> Dictionary:
    var attacks: Dictionary = BossBrain.config().get("attacks", {})
    return attacks.get(config_key, {})


func weight() -> float:
    return float(cfg().get("weight", 1.0))


func allowed_in(phase: int) -> bool:
    for p in cfg().get("phases", [1, 2, 3]):
        if int(p) == phase:
            return true
    return false


func start(by: Enemy, at: Node2D) -> void:
    boss = by
    target = at
    _extra_recover = 0.0
    _enter(Step.TELEGRAPH)
    _start_pulse()
    BossBullets.sound(telegraph_sound, boss.global_position)
    _on_telegraph()


## Advances the attack. Returns true once it has fully recovered.
func tick(delta: float) -> bool:
    if step == Step.DONE:
        return true
    boss.velocity = Vector2.ZERO
    _time += delta
    match step:
        Step.TELEGRAPH:
            _face_target()
            _telegraph_tick(delta)
            if _time >= float(cfg().get("telegraph", 0.6)):
                _stop_pulse()
                _enter(Step.ACTIVE)
                BossBullets.sound(active_sound, boss.global_position)
                _on_active()
        Step.ACTIVE:
            if _active_tick(delta):
                _on_active_end()
                _enter(Step.RECOVER)
        Step.RECOVER:
            if _time >= float(cfg().get("recover", 1.0)) * _brain_recover_mult() + _extra_recover:
                _enter(Step.DONE)
    return step == Step.DONE


## Ends the attack early (phase change, death) and undoes anything it put on
## the boss. Safe to call on an attack that is not running.
func stop() -> void:
    _stop_pulse()
    if step == Step.TELEGRAPH or step == Step.ACTIVE:
        _on_active_end()
    _enter(Step.DONE)


func is_running() -> bool:
    return step != Step.DONE


## True while the boss must take no damage from this attack's state (the
## Burrow, underground). `BossBrain` asks this before every hit.
func blocks_damage() -> bool:
    return false


## The brain's random source, so a seeded test is repeatable.
func _rng() -> RandomNumberGenerator:
    var brain := get_parent() as BossBrain
    return brain.rng if brain != null else RandomNumberGenerator.new()


## This attack's damage: `base_key` (a config number) times the boss's damage
## stat, the same scaling every coin uses.
func _damage(base_key: String, fallback: float) -> float:
    return float(cfg().get(base_key, fallback)) * boss.stats.get_stat("damage")


# --- hooks ------------------------------------------------------------------

func _on_telegraph() -> void:
    pass


func _telegraph_tick(_delta: float) -> void:
    pass


func _on_active() -> void:
    pass


## Returns true when the active part is over. The default fires once and ends.
func _active_tick(_delta: float) -> bool:
    return true


## Runs once when the active part ends, or when the attack is stopped before.
func _on_active_end() -> void:
    pass


# --- helpers ----------------------------------------------------------------

func _enter(next: int) -> void:
    step = next
    _time = 0.0


func _aim() -> Vector2:
    if target == null or not is_instance_valid(target):
        return Vector2.LEFT if boss.sprite.flip_h else Vector2.RIGHT
    var to_target := target.global_position - boss.global_position
    return to_target.normalized() if to_target.length() > 0.001 else Vector2.RIGHT


func _face_target() -> void:
    boss.sprite.flip_h = _aim().x < 0


## The glow on the `Node2D` container, not the sprite: `HitFlashManager`
## tweens the sprite's own modulate and would wipe it.
func _start_pulse() -> void:
    _stop_pulse()
    if boss.visual == null or not boss.is_inside_tree():
        return
    _pulse = boss.create_tween().set_loops()
    _pulse.tween_property(boss.visual, "modulate", telegraph_color, 0.15)
    _pulse.tween_property(boss.visual, "modulate", _rest_tint(), 0.15)


func _stop_pulse() -> void:
    if _pulse != null and _pulse.is_valid():
        _pulse.kill()
    _pulse = null
    if boss != null and is_instance_valid(boss) and boss.visual != null:
        boss.visual.modulate = _rest_tint()


## Recovery multiplier from the brain (shorter once enraged).
func _brain_recover_mult() -> float:
    var brain := get_parent() as BossBrain
    return brain.recover_mult() if brain != null else 1.0


## The boss's tint between telegraphs (red once enraged).
func _rest_tint() -> Color:
    var brain := get_parent() as BossBrain
    return brain.rest_tint() if brain != null else Color.WHITE


## An impact: `impact_sound` at `at`, and the camera kicked by `shake.<moment>`.
func _impact(at: Vector2, moment: String) -> void:
    BossBullets.sound(impact_sound, at)
    BossBullets.shake(boss, moment)
