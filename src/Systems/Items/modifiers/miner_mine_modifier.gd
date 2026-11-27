extends BaseModifier
## The Miner's signature. His weapons never fire on their own (`hold_fire`) and
## he can carry ranged weapons only (`ranged_only`). Instead, every
## `lay_interval` seconds a `Mine` drops under him packed with every projectile
## his weapons would have fired in that time, at `damage_multiplier` damage to
## make up for flying in random directions. Numbers come from the `miner_mine`
## block of `game_config.json`. Character-only: its generation weight is 0.

@export var display_name: String = "Minefield"
## One is picked at random each time a mine is laid
## (`src/Assets/sounds/miner/lay/`).
@export var lay_sounds: Array[AudioStream] = []

var _timer: Timer
var _mines: Array[Mine] = []
## The unfinished attack carried into the next mine, per weapon, as a fraction
## of one attack. A weapon attacking every 1.2 s packs 1 attack into the first
## 2 s mine and carries the 0.8 s it had charged, so the second mine gets 2.
## Only whole attacks are packed, so a shotgun always drops full pellet volleys.
var _carry: Dictionary = {}


static func config() -> Dictionary:
	return GameConfig.section("miner_mine")


func get_tooltip_stats() -> String:
	var c := config()
	return "Weapons hold fire. Every %ss a mine is laid with their shots (+%d%% damage), fired in random directions when an enemy steps on it" % [
		str(float(c.get("lay_interval", 2.0))), roundi((float(c.get("damage_multiplier", 1.5)) - 1.0) * 100.0)]


func attachEventManager(em: Node):
	_cache_holder(em)
	_set_holder_flags(true)
	_timer = Timer.new()
	_timer.wait_time = float(config().get("lay_interval", 2.0))
	_timer.autostart = true  # starts once in the tree, even if attached off-tree
	_timer.timeout.connect(lay_mine)
	add_child(_timer)


func detach() -> void:
	_set_holder_flags(false)
	super.detach()


func _set_holder_flags(on: bool) -> void:
	var weapon_holder := _weapon_holder()
	if weapon_holder:
		weapon_holder.ranged_only = on
		weapon_holder.hold_fire = on


func _weapon_holder() -> WeaponHolder:
	if not is_instance_valid(holder):
		return null
	return holder.get_node_or_null("WeaponHolder") as WeaponHolder


## Drops one mine under the holder and returns it, or null when there is
## nothing to pack (no ranged weapon, or not a whole attack charged yet).
func lay_mine() -> Mine:
	var weapon_holder := _weapon_holder()
	if weapon_holder == null or not holder.is_inside_tree():
		return null
	var c := config()
	var interval := float(c.get("lay_interval", 2.0))
	var mine := Mine.new()
	var carry := {}
	for weapon in weapon_holder.weapons:
		if not (weapon is ProjectileWeapon):
			continue
		var attacks: float = _carry.get(weapon, 0.0) + weapon.attack_speed_with(stats) * interval
		var whole := floori(attacks + 0.000001)  # float sums like 3 x 0.333.. still count as whole
		carry[weapon] = maxf(attacks - whole, 0.0)
		if whole > 0:
			mine.charges.append([weapon, whole * weapon.projectiles_per_attack()])
	_carry = carry  # drops sold weapons
	if mine.charges.is_empty():
		mine.free()
		return null

	mine.damage_multiplier = float(c.get("damage_multiplier", 1.5))
	mine.radius = Stats.meters_to_px(float(c.get("trigger_radius", 0.1)))
	mine.global_position = (holder as Node2D).global_position
	holder.get_tree().current_scene.add_child(mine)
	if not lay_sounds.is_empty():
		SoundManager.play(lay_sounds.pick_random(), float(c.get("lay_sound_db", 0.0)), 0.1)

	_mines.assign(_mines.filter(func(m): return is_instance_valid(m)))
	_mines.append(mine)
	while _mines.size() > int(c.get("max_mines", 12)):
		_mines.pop_front().queue_free()
	return mine
