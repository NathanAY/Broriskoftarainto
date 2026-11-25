## The final boss's coin projectiles, and the two patterns every coin attack is
## built from: a fan aimed at a direction and a ring with a gap.
##
## A coin is the shared `Projectile.tscn` wearing the coin art, so it hits
## through `Damage.deal` like a Gunner's bullet. It carries no weapon, so it
## never procs the boss's on-hit effects. Coins are added to the current scene,
## never to the enemies container: `StageManager` ends a phase when that
## container is empty, and a coin in flight must not hold the phase open.
class_name BossBullets
extends RefCounted

const PROJECTILE_SCENE := preload("res://src/Systems/weapon/Projectile.tscn")
const COIN_TEXTURE := preload("res://src/Assets/boss/boss_coin.png")
const BURST_SCENE := preload("res://src/Scenes/particles/explosion_burst.tscn")


## Fires one coin from `boss` along `direction`. `damage_mult` and `speed_mult`
## scale the shared coin numbers for one attack.
static func fire(boss: Enemy, direction: Vector2, damage_mult: float = 1.0, speed_mult: float = 1.0) -> Projectile:
    var config := BossBrain.config()
    var size := float(config.get("coin_size", 28.0))
    var coin: Projectile = PROJECTILE_SCENE.instantiate()
    coin.scale = Vector2.ONE
    var sprite := coin.get_node("Sprite2D") as Sprite2D
    sprite.texture = COIN_TEXTURE
    sprite.scale = Vector2.ONE * (size / COIN_TEXTURE.get_width())
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    var shape_node := coin.get_node("CollisionShape2D") as CollisionShape2D
    shape_node.scale = Vector2.ONE
    var circle := CircleShape2D.new()
    circle.radius = size * float(config.get("coin_hit_radius", 0.4))
    shape_node.shape = circle

    coin.life_time = float(config.get("coin_life", 4.0))
    coin.base_speed = float(config.get("coin_speed", 260.0)) * speed_mult
    coin.damage = float(config.get("coin_damage", 3.0)) * damage_mult * boss.stats.get_stat("damage")
    coin.attachEventManager(boss.event_manager)
    coin.set_ignore_groups(["enemies"])
    coin.global_position = boss.global_position
    coin.set_direction(direction)
    world(boss).add_child(coin)
    return coin


## `count` coins spread evenly over `spread_deg`, centred on `direction`.
static func fan(boss: Enemy, direction: Vector2, count: int, spread_deg: float,
        damage_mult: float = 1.0, speed_mult: float = 1.0) -> Array[Projectile]:
    var coins: Array[Projectile] = []
    var spread := deg_to_rad(spread_deg)
    for i in count:
        var offset := 0.0 if count <= 1 else -spread * 0.5 + spread * i / float(count - 1)
        coins.append(fire(boss, direction.rotated(offset), damage_mult, speed_mult))
    return coins


## A full ring of `count` evenly spaced slots with `gap` slots left empty,
## centred on `gap_direction`, so the player has one way through.
static func ring(boss: Enemy, count: int, gap: int, gap_direction: Vector2,
        damage_mult: float = 1.0, speed_mult: float = 1.0) -> Array[Projectile]:
    var coins: Array[Projectile] = []
    var step := TAU / count
    # Slots sit half a step either side of the gap's centre, so an even gap is
    # centred exactly on the aim and an odd one on its middle slot.
    var first := gap_direction.angle() - step * (gap - 1) * 0.5
    for i in count:
        if i < gap:
            continue
        coins.append(fire(boss, Vector2.from_angle(first + step * i), damage_mult, speed_mult))
    return coins


## An explosion at `at`: every damageable body that is not an enemy within
## `radius_px` takes `damage`, and the shared blast visual plays at that radius.
## A group scan rather than a physics overlap, like `AreaBurstOnEnter`, so the
## hit lands on the frame it is called. Returns how many bodies it hit.
static func blast(boss: Enemy, at: Vector2, radius_px: float, damage: float) -> int:
    burst_visual(boss, at, radius_px)
    var hits := 0
    for node in victims(boss):
        if node.global_position.distance_to(at) <= radius_px and hurt(boss, node, damage, "explosion"):
            hits += 1
    return hits


## The shared blast visual alone, sized to `radius_px`. No damage.
static func burst_visual(boss: Enemy, at: Vector2, radius_px: float) -> void:
    var burst := BURST_SCENE.instantiate() as ExplosionBurst
    burst.radius = radius_px
    world(boss).add_child(burst)
    burst.global_position = at


## Everything the boss's area attacks can hurt: damageable bodies that are not
## enemies. A group scan, so a hit lands on the frame it is asked for.
static func victims(boss: Enemy) -> Array[Node2D]:
    var found: Array[Node2D] = []
    for body in boss.get_tree().get_nodes_in_group("damageable"):
        var node := body as Node2D
        if node != null and not node.is_in_group("enemies"):
            found.append(node)
    return found


## One hit from the boss's area attacks. No weapon, so it never procs on-hit.
static func hurt(boss: Enemy, node: Node2D, damage: float, tag: String) -> bool:
    var ctx := DamageContext.new()
    ctx.source = boss
    ctx.target = node
    ctx.base_amount = damage
    ctx.final_amount = damage
    ctx.tags.append(tag)
    return Damage.deal(ctx, boss.event_manager)


## Kicks the camera by the `shake.<moment>` config value (px, before the
## options slider). No camera, or one without `shake()`, is a no-op.
static func shake(node: Node, moment: String) -> void:
    var camera := node.get_viewport().get_camera_2d() if node.is_inside_tree() else null
    if camera != null and camera.has_method("shake"):
        var amounts: Dictionary = BossBrain.config().get("shake", {})
        camera.shake(float(amounts.get(moment, 0.0)))


## Plays a boss sound at `at`, at the `sound_volume_db` config level.
static func sound(stream: AudioStream, at: Vector2) -> void:
    if stream != null:
        SoundManager.play2d(stream, at, float(BossBrain.config().get("sound_volume_db", -6.0)), 0.12)


## Clamps `pos` into the arena, when there is one.
static func clamp_to_arena(boss: Node, pos: Vector2, margin: float = 0.0) -> Vector2:
    var arena := boss.get_tree().get_first_node_in_group("arena") as Arena
    if arena == null:
        return pos
    return arena.clamp_to_arena(pos, margin)


## Where boss effects are parented: the current scene, never the enemies
## container (see the class comment).
static func world(boss: Enemy) -> Node:
    var scene := boss.get_tree().current_scene
    return scene if scene != null else boss.get_tree().root
