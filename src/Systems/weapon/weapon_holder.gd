extends Node
class_name WeaponHolder

## The entity that owns this holder - always this node's parent.
##
## Resolved on access rather than with `@onready`. `@onready` waits for `_ready`,
## so the field read as null for as long as the holder was detached from the
## tree, which forced every caller that equips off-tree to wire this by hand.
## `get_parent()` is valid the moment the node is parented, tree or no tree, and
## resolving it per access also means a re-parent is picked up automatically and a
## freed owner reads as null instead of dangling.
var hold_owner: Node:
    get:
        return get_parent()

## Resolved on access for the same reason as `hold_owner`.
var event_manager: EventManager:
    get:
        var owner_node := hold_owner
        if owner_node == null:
            return null
        return owner_node.get_node_or_null("EventManager") as EventManager
@export var weapons: Array[BaseWeapon] = []   # list of Weapon .tres resources (templates)
## How many weapons this holder may carry; 0 is no limit. The player's holder
## sets 6 in `Character.tscn`. Enemies keep 0 - the boss carries more than six.
@export var max_weapons: int = 0
## Refuses every weapon that is not a `ProjectileWeapon`. Set by the Miner's
## `MinerMineModifier`, which can only pack projectiles into its mines.
var ranged_only: bool = false
## Weapons keep aiming but never fire on their own timer. Also the Miner's:
## the mine fires their shots instead.
var hold_fire: bool = false
# visual placement config
## How far from the holder each weapon sprite orbits, in **meters**. Converted
## to pixels in `_get_weapon_position`, the only place a `Vector2` is built.
@export var weapon_orbit_radius: float = 0.2

# `weapons` above is the single source of truth: every equipped weapon is one
# entry, and `BaseWeapon.sprite_node` points at the one WeaponVisual node that
# represents it in the tree, named after the weapon (e.g. "Shotgun"). A weapon
# is a Resource, so that node is what makes it visible at all - there is no
# weapon -> node lookup table.

# runtime state: map weapon_instance -> Timer
var weapon_timers: Dictionary = {}   # key: weapon_instance (Resource), value: Timer

## Every weapon that has already been through `add_weapon`, keyed by the live
## instance. `_ready()` runs on *every* tree entry, and `add_weapon` appends the
## live instance it creates back onto `weapons`, so after the first entry that
## array holds instances which are already equipped.
##
## Without this record a second tree entry re-equips every weapon, and that is
## not merely a duplicate: a GDScript `for` over an Array re-reads the size each
## pass, so `add_weapon` appending inside the loop body makes the loop extend
## itself and never terminate. The second tree entry hangs the game.
var equipped: Dictionary = {}

func _ready() -> void:
    # Equipping is deferred by one idle frame on purpose. `_ready` runs while the
    # parent is still propagating tree entry, and `BaseWeapon.apply_to` does
    # `holder.add_child(timer)`; on a parent that is busy setting up children
    # that add_child fails, so the weapon ends up equipped with no firing timer
    # and can never shoot. One frame later the parent is settled and it works.
    #
    # Nothing else is deferred: `add_weapon` stays synchronous, so every runtime
    # equip (shop purchase, weapon pickup) still takes effect immediately.
    _equip_preplaced_weapons.call_deferred()

## Consumes the editor-populated `weapons` export, equipping each entry once.
## Runs deferred out of `_ready` - see the note there for why.
func _equip_preplaced_weapons() -> void:
    # The iteration runs over a snapshot for the same reason `equipped` exists:
    # `add_weapon` appends to `weapons`, so looping over `weapons` directly would
    # extend the loop with each element added. The `equipped` check is what stops
    # a weapon being equipped twice; the snapshot is what guarantees the loop
    # terminates even if that check were ever wrong.
    for template in weapons.duplicate():
        if equipped.has(template):
            continue
        # A pre-placed entry is a .tres template, not a live instance. Drop it once
        # consumed so `weapons` only ever holds equipped weapons - a leftover
        # template would still be counted by `_reposition_weapons` and would shift
        # every other weapon's slot around the orbit.
        weapons.erase(template)
        add_weapon(template)

func _process(_delta: float) -> void:
    for weapon in weapons:
        if weapon:
            weapon.aim()

func is_full() -> bool:
    return max_weapons > 0 and weapons.size() >= max_weapons

## Slots still open; always 0 for a holder with no limit.
func free_slots() -> int:
    return maxi(max_weapons - weapons.size(), 0)

## Heading for a weapons list: "Weapons 2/6", or plain "Weapons" with no limit.
func slots_title() -> String:
    if max_weapons <= 0:
        return "Weapons"
    return "Weapons %d/%d" % [weapons.size(), max_weapons]

## An equipped weapon `weapon` could be combined with, or null. `weapon` may be
## an equipped instance (its partner is another one) or a template on offer.
func find_combinable(weapon: BaseWeapon) -> BaseWeapon:
    if weapon == null:
        return null
    for equipped_weapon in weapons:
        if equipped_weapon and equipped_weapon.can_combine_with(weapon):
            return equipped_weapon
    return null

## Whether `add_weapon` would take this weapon: there is a free slot, or it can
## be combined into a weapon already held.
func can_add_weapon(weapon_resource: BaseWeapon) -> bool:
    return accepts_kind(weapon_resource) \
            and (not is_full() or find_combinable(weapon_resource) != null)

## Whether this holder takes this kind of weapon at all, slots aside.
func accepts_kind(weapon_resource: BaseWeapon) -> bool:
    return weapon_resource != null and (not ranged_only or weapon_resource is ProjectileWeapon)

## Merges an equipped weapon with its equipped duplicate: the duplicate is
## removed and `weapon_inst` climbs one rarity. Returns false when it has no
## duplicate of the same rarity (or is already legendary).
func combine(weapon_inst: BaseWeapon) -> bool:
    if not (weapon_inst in weapons):
        return false
    var partner := find_combinable(weapon_inst)
    if partner == null:
        return false
    remove_weapon(partner)
    _raise_rarity(weapon_inst)
    return true

func _raise_rarity(weapon_inst: BaseWeapon) -> void:
    weapon_inst.rarity = (weapon_inst.rarity + 1) as BaseWeapon.Rarity
    if event_manager:
        event_manager.emit_event("on_weapon_changes", {"weapon_inst": weapon_inst, "hold_owner": hold_owner})

## Equips a copy of `weapon_resource`. With every slot taken it is combined into
## an equipped duplicate instead, and refused (false) when there is none.
func add_weapon(weapon_resource: BaseWeapon) -> bool:
    if not accepts_kind(weapon_resource):
        return false
    if is_full():
        var partner := find_combinable(weapon_resource)
        if partner == null:
            return false
        _raise_rarity(partner)
        return true
    # Duplicate the resource so we have an independent instance per holder
    var weapon_inst: BaseWeapon = weapon_resource.duplicate(true)
    # Keep the duplicate in our weapons list (so remove_weapon can match it)
    weapons.append(weapon_inst)
    # Record it as equipped before touching the tree, so `_ready` treats it as
    # already handled if it re-runs while `apply_to` is still setting up.
    equipped[weapon_inst] = true
    # Equip (create timer + start firing)
    _equip_weapon(weapon_inst)
    if event_manager:
        event_manager.emit_event("on_weapon_changes", {"weapon_inst": weapon_inst, "hold_owner": hold_owner})
    return true

func remove_weapon(weapon_inst: BaseWeapon) -> void:
    if not weapon_inst:
        return
    if not (weapon_inst in weapons):
        return
    # remove modifiers, timer and the WeaponVisual node (remove_from frees
    # sprite_node, which is the weapon's only node)
    if weapon_inst.has_method("remove_from"):
        weapon_inst.remove_from(hold_owner)
    # stop & free timer
    if weapon_timers.has(weapon_inst):
        var t: Timer = weapon_timers[weapon_inst]
        if is_instance_valid(t):
            t.stop()
            t.queue_free()
        weapon_timers.erase(weapon_inst)
    # remove from list
    weapons.erase(weapon_inst)
    # and forget that it was ever equipped, so a later tree entry does not treat
    # it as live. `add_weapon` always hands out a fresh duplicate, so this cannot
    # make a stale instance re-equip itself.
    equipped.erase(weapon_inst)
    # reposition remaining visuals
    _reposition_weapons()
    if event_manager:
        event_manager.emit_event("on_weapon_changes", {"weapon_inst": weapon_inst, "hold_owner": hold_owner})

func _equip_weapon(weapon_inst: BaseWeapon) -> void:
    # Apply modifiers and set holder on the weapon instance (Weapon.apply_to expects holder)
    if weapon_inst.has_method("apply_to"):
        weapon_inst.apply_to(hold_owner)
    else:
        push_warning("WeaponHolder: weapon has no apply_to method")
    if weapon_inst.sprite:
        weapon_inst.sprite_node = _create_visual(weapon_inst)
    _reposition_weapons() 

# The single node that represents the weapon in the scene tree. It sits at the
# WeaponHolder's origin, so the visual's global position and rotation stay
# identical to when it was parented to the holder directly.
func _create_visual(weapon_inst: BaseWeapon) -> WeaponVisual:
    var visual := WeaponVisual.new()
    visual.name = _unique_visual_name(weapon_inst.name)
    visual.texture = weapon_inst.sprite
    visual.scale = Vector2.ONE * minf(1.0, AssetSizes.scale_for(visual.texture, AssetSizes.WEAPON_SPRITE)) * weapon_inst.sprite_scale
    visual.weapon = weapon_inst
    # The visual used to be appended as the last child of the holder, so it drew
    # on top of the holder's other visuals (body, legs, hit particles). Nesting
    # it under the WeaponHolder changes the tree order, so restore that here.
    visual.z_index = 1
    add_child(visual)
    return visual

# Godot node names cannot contain . : @ / " % and two weapons may share a name,
# so a taken name gets a numeric suffix ("Shotgun", "Shotgun2", ...).
func _unique_visual_name(weapon_name: String) -> String:
    var base := ""
    for c in weapon_name:
        if c not in [".", ":", "@", "/", "\\", "\"", "%"]:
            base += c
    if base.is_empty():
        base = "Weapon"
    var candidate := base
    var suffix := 2
    while has_node(NodePath(candidate)):
        candidate = "%s%d" % [base, suffix]
        suffix += 1
    return candidate

func _reposition_weapons() -> void:
    var count := weapons.size()
    if count == 0:
        return
    for i in range(count):
        var weapon_inst = weapons[i]
        var node: Sprite2D = weapon_inst.sprite_node if weapon_inst else null
        if not is_instance_valid(node):
            continue
        node.position = _get_weapon_position(i, count)
        _update_weapon_orientation(node, i, count)


## Angle of orbit slot `index` of `count`, in radians (+y is down, so PI/2 is the
## bottom of the character). Odd counts put one weapon at bottom centre; even
## counts are rotated half a step so none sits there (2 = left/right, 4 = an X).
static func slot_angle(index: int, count: int) -> float:
    var half_step := 0.0 if count % 2 == 1 else 0.5
    return PI / 2.0 + TAU * (float(index) + half_step) / float(count)


func _get_weapon_position(index: int, count: int) -> Vector2:
    if count <= 0:
        return Vector2.ZERO
    var angle := slot_angle(index, count)
    return Vector2(cos(angle), sin(angle)) * Stats.meters_to_px(weapon_orbit_radius)

func _update_weapon_orientation(node: Sprite2D, index: int, count: int):
    var angle := slot_angle(index, count)
    node.rotation = angle

    # Flip vertically if weapon is on left side (x < 0)
    var dir := Vector2(cos(angle), sin(angle))
    node.flip_v = dir.x < 0
