# RegenModifier.gd
extends Node

@export var heal_amount: float = 4.0   # heal per tick
@export var heal_amount_percent: float = 0.01   # heal% of max life per tick
@export var interval: float = 3.0      # seconds
var event_manager: EventManager
var stacks: int = 0
var holder: Node = null

var _regen_timer: Timer

func attachEventManager(em: EventManager):
    event_manager = em
    holder = em.get_parent()
    em.subscribe("on_item_added", Callable(self, "_on_item_added"))
    em.subscribe("on_item_removed", Callable(self, "_on_item_removed"))

    # setup regen timer
    _regen_timer = Timer.new()
    _regen_timer.wait_time = interval
    _regen_timer.autostart = true
    _regen_timer.one_shot = false
    _regen_timer.timeout.connect(_on_regen_tick)
    add_child(_regen_timer)

func _on_item_added(event):
    if event.get("item").resource_path.ends_with("RegenPassive.tres"):
        stacks += 1

func _on_item_removed(event):
    if event.get("item").resource_path.ends_with("RegenPassive.tres"):
        stacks = max(0, stacks - 1)

func _on_regen_tick():
    if stacks <= 0:
        return
    if holder and holder.has_node("Health"):
        var h: Health = holder.get_node("Health")
        h.heal((heal_amount + (h.max_health * heal_amount_percent)) * stacks)
