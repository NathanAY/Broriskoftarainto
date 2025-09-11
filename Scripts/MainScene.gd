extends Node2D

@onready var tower = $Tower
@onready var spawner = $Spawner

var enemy_scene = preload("res://Scenes/Enemy.tscn")

func _ready():
    # Set the tower position to center
    var screen_size = get_viewport().get_visible_rect().size
    
    # Start spawning enemies
    #spawner.spawn_enemy()
