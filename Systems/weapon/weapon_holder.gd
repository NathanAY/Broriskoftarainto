extends Node

@onready var hold_owner: Node = get_parent()
@onready var stats: Node = hold_owner.get_node_or_null("Stats")
@onready var event_manager: Node = hold_owner.get_node_or_null("EventManager")

@export var weapons: Array[BaseWeapon] = []   # list of Weapon .tres resources (templates)

# runtime state: map weapon_instance -> Timer
var weapon_timers: Dictionary = {}   # key: weapon_instance (Resource), value: Timer

func _ready() -> void:
    # equip any weapons pre-placed in the exported array
    for w in weapons:
        add_weapon(w)

    # update timers when stats change (so attack_speed changes apply)
    if event_manager:
        event_manager.subscribe("on_stat_changes", Callable(self, "_on_stat_changes"))

func add_weapon(weapon_resource: BaseWeapon) -> void:
    if weapon_resource == null:
        return

    # Duplicate the resource so we have an independent instance per holder
    var weapon_inst: BaseWeapon = weapon_resource.duplicate(true)
    # Keep the duplicate in our weapons list (so remove_weapon can match it)
    weapons.append(weapon_inst)

    # Apply modifiers and set holder on the weapon instance (Weapon.apply_to expects holder)
    if weapon_inst.has_method("apply_to"):
        weapon_inst.apply_to(hold_owner)
    else:
        push_warning("WeaponHolder: weapon has no apply_to method")

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

    # remove from list
    weapons.erase(weapon_inst)

    if event_manager:
        event_manager.emit_event("on_weapon_removed", [hold_owner, weapon_inst])

func _equip_weapon(weapon_inst: BaseWeapon) -> void:
    # ensure modifiers applied (duplicate safe)
    if weapon_inst.has_method("apply_to"):
        weapon_inst.apply_to(hold_owner)

    # create a timer for this specific weapon instance
    var timer := Timer.new()
    timer.one_shot = false
    # compute initial wait_time using owner's stats + weapon base
    timer.wait_time = _compute_weapon_wait_time(weapon_inst)
    add_child(timer)

    # connect the timeout to a bound callable so it calls with the correct weapon_inst
    timer.timeout.connect(Callable(self, "_on_weapon_timeout").bind(weapon_inst))
    timer.start()
    weapon_timers[weapon_inst] = timer


func _on_weapon_timeout(weapon_inst: BaseWeapon) -> void:
    #called from timer; find a target and ask the weapon instance to shoot
    if weapon_inst == null:
        return
    if not (weapon_inst in weapon_timers):
        return
    
    var targets: Array[Node] = []
    if weapon_inst.target_selector:
        targets = weapon_inst.target_selector.find_targets(hold_owner, weapon_inst.range)
    
    if targets.size() > 0:
        if weapon_inst.has_method("try_shoot"):
            weapon_inst.try_shoot(targets)
    

func _compute_weapon_wait_time(weapon_inst: BaseWeapon) -> float:
    var base_weapon_speed := 0.0
    if weapon_inst.base_attack_speed:
        base_weapon_speed = float(weapon_inst.base_attack_speed)
    var owner_speed := 0.0
    if stats and stats.has_method("get_stat"):
        owner_speed = stats.get_stat("attack_speed")
    # defend against zero/negative combined speed
    var combined = owner_speed * base_weapon_speed
    if combined <= 0.001:
        combined = 0.001
    return 1.0 / combined

# when stats change, update all timers so attack_speed changes apply immediately
func _on_stat_changes(event) -> void:
    for weapon_inst in weapon_timers.keys():
        var t: Timer = weapon_timers[weapon_inst]
        if is_instance_valid(t):
            t.wait_time = _compute_weapon_wait_time(weapon_inst)
