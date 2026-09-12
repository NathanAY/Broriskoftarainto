extends Control

@export var event_manager: EventManager
@onready var background: ColorRect = $Background
@onready var health_fill: ColorRect = $HealthFill
@onready var shield_fill: ColorRect = $ShieldFill
@onready var label: Label = $Label

var max_health: float = 0
var current_health: float = 0
var max_shield: float = 0
var current_shield: float = 0

func _ready() -> void:
    event_manager.subscribe("on_health_changed", Callable(self, "_on_health_changed"))
    event_manager.subscribe("on_shield_changed", Callable(self, "_on_shield_changed"))

    background.color = Color(0.2, 0.2, 0.2)  # dark gray
    health_fill.color = Color(1, 0, 0)       # red
    shield_fill.color = Color.LIGHT_SKY_BLUE
    visible = false

func _on_health_changed(event: Dictionary) -> void:
    max_health = event.get("max_health", 1)
    current_health = event.get("current_health", 0)
    _update_bar()

func _on_shield_changed(event: Dictionary) -> void:
    max_shield = event.get("max_shield", 0)
    current_shield = event.get("current_shield", 0)
    _update_bar()

func _update_bar() -> void:
    var total_max = max_health + max_shield
    if total_max <= 0:
        visible = false
        return

    var total_width = background.size.x
    var total_height = background.size.y

    # --- Health ---
    var health_width_max = total_width * (max_health / total_max)
    var health_ratio = current_health / max_health
    var health_width = health_width_max * health_ratio

    health_fill.size = Vector2(health_width, total_height)
    health_fill.position = Vector2(0, 0)

    # --- Shield ---
    var shield_width_max = total_width * (max_shield / total_max)
    
    var shield_ratio = (current_shield / max_shield) if max_shield > 0 else 0
    var shield_width = shield_width_max * shield_ratio

    shield_fill.size = Vector2(shield_width, total_height)
    shield_fill.position = Vector2(health_width_max, 0)

    # --- Label ---
    label.text = str(int(current_health)) if max_shield == 0 else str(int(current_health)) + " | " + str(int(current_shield))

    visible = (current_health < max_health) or (current_shield < max_shield)
