extends Node
class_name WeaponHolder

@onready var hold_owner: Node = get_parent()
@onready var event_manager: Node = hold_owner.get_node_or_null("EventManager")
@export var weapons: Array[BaseWeapon] = []   # list of Weapon .tres resources (templates)
# visual placement config
@export var weapon_orbit_radius: float = 60.0
@export var angle_offset: float = -PI * 1  # start at top; change if you want different start angle

# keep a map: weapon_instance -> Node2D (the visual sprite node)
var weapon_templates: Dictionary = {}
# runtime state: map weapon_instance -> Timer
var weapon_timers: Dictionary = {}   # key: weapon_instance (Resource), value: Timer

func _ready() -> void:
    # equip any weapons pre-placed in the exported array
    for w in weapons:
        add_weapon(w)

func _process(delta: float) -> void:
    for weapon in weapons:
        if weapon:
            weapon.aim()

func add_weapon(weapon_resource: BaseWeapon) -> void:
    if weapon_resource == null:
        return
    # Duplicate the resource so we have an independent instance per holder
    var weapon_inst: BaseWeapon = weapon_resource.duplicate(true)
    # Keep the duplicate in our weapons list (so remove_weapon can match it)
    weapons.append(weapon_inst)
    # Equip (create timer + start firing)
    _equip_weapon(weapon_inst)
    if event_manager:
        event_manager.emit_event("on_weapon_added", [hold_owner, weapon_inst])

func remove_weapon(weapon_inst: BaseWeapon) -> void:
    if not weapon_inst:
        return
    if not (weapon_inst in weapons):
        return
    # remove modifiers
    if weapon_inst.has_method("remove_from"):
        weapon_inst.remove_from(hold_owner)
    # stop & free timer
    if weapon_timers.has(weapon_inst):
        var t: Timer = weapon_timers[weapon_inst]
        if is_instance_valid(t):
            t.stop()
            t.queue_free()
        weapon_timers.erase(weapon_inst)
    if weapon_templates.has(weapon_inst):
        var sprite_node = weapon_templates[weapon_inst]
        if is_instance_valid(sprite_node): sprite_node.queue_free()
        weapon_templates.erase(weapon_inst)
    # remove from list
    weapons.erase(weapon_inst)
    # reposition remaining visuals
    _reposition_weapons()
    if event_manager:
        event_manager.emit_event("on_weapon_removed", [hold_owner, weapon_inst])

func _equip_weapon(weapon_inst: BaseWeapon) -> void:
    # Apply modifiers and set holder on the weapon instance (Weapon.apply_to expects holder)
    if weapon_inst.has_method("apply_to"):
        weapon_inst.apply_to(hold_owner)
    else:
        push_warning("WeaponHolder: weapon has no apply_to method")
    if weapon_inst.sprite:
        var sprite_node := Sprite2D.new()
        sprite_node.texture = weapon_inst.sprite
        weapon_inst.sprite_node = sprite_node
        hold_owner.add_child(sprite_node)
        weapon_templates[weapon_inst] = sprite_node
    _reposition_weapons() 

func _reposition_weapons() -> void:
    var count := weapons.size()
    if count == 0:
        return
    for i in range(count):
        var weapon_inst = weapons[i]
        if weapon_templates.has(weapon_inst):
            var node: Sprite2D = weapon_templates[weapon_inst]
            if not is_instance_valid(node):
                continue
            node.position = _get_weapon_position(i, count)
            _update_weapon_orientation(node, i, count)


func _get_weapon_position(index: int, count: int) -> Vector2:
    if count <= 0:
        return Vector2.ZERO
    var angle := angle_offset + TAU * float(index) / float(count)
    return Vector2(cos(angle), sin(angle)) * weapon_orbit_radius

func _update_weapon_orientation(node: Sprite2D, index: int, count: int):
    var angle := angle_offset + TAU * float(index) / float(count)
    node.rotation = angle

    # Flip vertically if weapon is on left side (x < 0)
    var dir := Vector2(cos(angle), sin(angle))
    node.flip_v = dir.x < 0
