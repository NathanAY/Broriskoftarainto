extends Node2D

@onready var tower = $Tower
@onready var spawner = $Spawner

var enemy_scene = preload("res://Scenes/Enemy.tscn")

func _ready():
    # Set the tower position to center
    var screen_size = get_viewport().get_visible_rect().size
    
    # Start spawning enemies
    #spawner.spawn_enemy()

var _condition_update_accum: float = 0.0
var condition_update_interval: float = 3  # seconds                

#func _process(delta: float) -> void:
    #_condition_update_accum += delta
    #if _condition_update_accum <= condition_update_interval:
        #return
    #_condition_update_accum = 0.0
    #print_all_objects_by_type()
     #
#func print_all_objects_by_type():
    #var types := {}
    #print("Projectile count: ", Projectile.instance_count)
