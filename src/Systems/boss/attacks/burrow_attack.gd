## Burrow: sinks into the sand and travels underground as a dust mound that
## follows the player for `track_time`, stops for `lock_time`, then erupts:
## a blast of `erupt_radius` plus a coin ring from the eruption point.
## While underground the boss cannot be hit or targeted.
## Counterplay: once the mound stops, move away from it.
extends BossAttack

const MOUND_TEXTURE := preload("res://src/Assets/boss/burrow_mound.png")

## The mound while it travels; null otherwise. Read by the tests.
var mound: Sprite2D = null

var _underground: bool = false
var _saved_layers: Dictionary = {}


func blocks_damage() -> bool:
    return _underground


func _on_active() -> void:
    _go_under()
    mound = Sprite2D.new()
    mound.texture = MOUND_TEXTURE
    mound.scale = Vector2.ONE * (float(cfg().get("mound_size", 120.0)) / MOUND_TEXTURE.get_width())
    mound.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    BossBullets.world(boss).add_child(mound)
    mound.global_position = boss.global_position


func _active_tick(delta: float) -> bool:
    var track := float(cfg().get("track_time", 1.5))
    if _time < track and target != null and is_instance_valid(target):
        var to_target := target.global_position - mound.global_position
        var step_px := float(cfg().get("mound_speed", 420.0)) * delta
        mound.global_position = BossBullets.clamp_to_arena(boss,
                mound.global_position + to_target.limit_length(step_px), boss.body_radius())
    boss.global_position = mound.global_position
    if _time < track + float(cfg().get("lock_time", 0.5)):
        return false
    _erupt()
    return true


func _on_active_end() -> void:
    _come_up()
    if mound != null and is_instance_valid(mound):
        mound.queue_free()
    mound = null


func _erupt() -> void:
    _come_up()
    var at := boss.global_position
    BossBullets.blast(boss, at, float(cfg().get("erupt_radius", 130.0)), _damage("damage", 5.0))
    _impact(at, "erupt")
    BossBullets.ring(boss, int(cfg().get("ring_count", 16)), int(cfg().get("ring_gap", 2)), _aim(),
            float(cfg().get("ring_damage_mult", 1.0)), float(cfg().get("ring_speed_mult", 0.8)))


## Hides the boss and takes it off every layer and group a hit or a target
## selector could find it through. `blocks_damage()` covers anything left.
func _go_under() -> void:
    if _underground:
        return
    _underground = true
    var hitbox := boss.get_node("Hitbox") as Area2D
    _saved_layers = {
        "layer": boss.collision_layer,
        "hitbox_layer": hitbox.collision_layer,
        "hitbox_mask": hitbox.collision_mask,
    }
    boss.collision_layer = 0
    hitbox.collision_layer = 0
    hitbox.collision_mask = 0
    boss.remove_from_group("damageable")
    boss.visual.visible = false


func _come_up() -> void:
    if not _underground:
        return
    _underground = false
    var hitbox := boss.get_node("Hitbox") as Area2D
    boss.collision_layer = _saved_layers["layer"]
    hitbox.collision_layer = _saved_layers["hitbox_layer"]
    hitbox.collision_mask = _saved_layers["hitbox_mask"]
    if not boss.health_node.is_dead:
        boss.add_to_group("damageable")
    boss.visual.visible = true
