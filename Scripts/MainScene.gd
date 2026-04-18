extends Node2D

@onready var character = $Character
@onready var pause_menu: CanvasLayer = $UI/PauseMenu

func _ready():
    # Set the character position to center
    var screen_size = get_viewport().get_visible_rect().size
