extends Node
class_name StageManager

@export var stage_duration = 5         # seconds per stage
@export var character: Character

@onready var enemy_spawner: EnemySpawner = $EnemySpawner

var shop_portal_scene = preload("res://Systems/ShopPortal.tscn")

var enemiesNode: Node = null

@export var stage_time_elapsed: float = 0.0
@export var current_stage: int = 1

var stage_active: bool = true

func _ready():
    enemiesNode = get_node("../Nodes/Enemies")

func _process(delta: float) -> void:
    if not stage_active:
        return
    stage_time_elapsed += delta
    # End stage if time expired and all enemies dead
    if stage_time_elapsed >= stage_duration:
        enemy_spawner.spawn_active = false
        if enemiesNode.get_child_count() == 0:
            _end_stage()

func _end_stage():
    stage_active = false
    # spawn shop portal near character
    var portal = shop_portal_scene.instantiate()
    portal.global_position = character.global_position + Vector2(0, -100) # above the character
    get_tree().current_scene.get_node("Nodes").add_child(portal)
    var menu: ShopMenu = get_tree().current_scene.get_node_or_null("UI/ShopMenu")
    if menu:
        menu.next_stage_pressed.connect(_on_next_stage_confirmed, CONNECT_ONE_SHOT)
 
func _on_next_stage_confirmed():
    stage_active = true
    enemy_spawner.spawn_active = true
    enemy_spawner._on_next_stage()
    current_stage += 1
    stage_time_elapsed = 0.0
