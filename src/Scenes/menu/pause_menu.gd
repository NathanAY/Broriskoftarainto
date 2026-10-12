extends CanvasLayer

@onready var resume_button: Button = $Control/VBoxContainer/ResumeButton
@onready var restart_button: Button = $Control/VBoxContainer/RestartButton
@onready var new_run_button: Button = $Control/VBoxContainer/NewRunButton
@onready var character_button: Button = $Control/VBoxContainer/CharacterButton
@onready var options_button: Button = $Control/VBoxContainer/OptionsButton
@onready var main_menu_button: Button = $Control/VBoxContainer/MainMenuButton
@onready var exit_button: Button = $Control/VBoxContainer/ExitButton

const MAIN_MENU_SCENE_PATH := "res://src/Scenes/menu/Main.tscn"

@onready var options_menu: CanvasLayer = $OptionsMenu
@onready var character_menu: Control = $CharacterUi


var configure_panel_inst = null
var configure_menu_scene: PackedScene = null
var configure_enemy_panel_inst = null

func _ready():
    resume_button.pressed.connect(_on_resume_pressed)
    restart_button.pressed.connect(_on_restart_pressed)
    new_run_button.pressed.connect(_on_new_run_pressed)
    character_button.pressed.connect(_on_character_pressed)
    options_button.pressed.connect(_on_options_pressed)
    # Add Configure button dynamically so the scene file doesn't need editing
    var cfg_btn = UiMenuButton.new()
    cfg_btn.text = "Configure"
    cfg_btn.pressed.connect(_on_configure_pressed)
    $Control/VBoxContainer.add_child(cfg_btn)
    # The same panel pointed at the enemy nearest the player. Added here rather
    # than in the scene file for the same reason as the button above.
    var enemy_cfg_btn = UiMenuButton.new()
    enemy_cfg_btn.text = "Configure enemy"
    enemy_cfg_btn.pressed.connect(_on_configure_enemy_pressed)
    $Control/VBoxContainer.add_child(enemy_cfg_btn)
    # preload ConfigureMenu scene so it behaves like options_menu
    configure_menu_scene = load("res://src/Scenes/menu/ConfigureMenu.tscn")
    main_menu_button.pressed.connect(_on_main_menu_pressed)
    exit_button.pressed.connect(_on_exit_pressed)
    options_menu.visible = false
    character_menu.visible = false

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"): # Esc by default
        toggle_pause()

func toggle_pause():
    if get_tree().paused:
        _resume_game()
    else:
        _pause_game()

func _pause_game():
    get_tree().paused = true
    visible = true

func _resume_game():
    get_tree().paused = false
    visible = false

func _on_resume_pressed():
    _resume_game()

func _on_restart_pressed():
    get_tree().paused = false
    get_tree().reload_current_scene()

func _on_character_pressed():
    $Control.visible = false
    character_menu.visible = true

func _on_options_pressed():
    $Control.visible = false
    options_menu.visible = true

func _on_configure_pressed():
    # Show configure menu similarly to options_menu
    if configure_panel_inst and is_instance_valid(configure_panel_inst):
        configure_panel_inst.visible = true
        $Control.visible = false
        return
    if not configure_menu_scene:
        push_warning("ConfigureMenu scene not found")
        return
    configure_panel_inst = configure_menu_scene.instantiate()
    # Add as a child of this node so visibility toggling mirrors options_menu usage
    add_child(configure_panel_inst)
    $Control.visible = false
    configure_panel_inst.visible = true
    if configure_panel_inst.has_signal("closed"):
        configure_panel_inst.connect("closed", Callable(self, "_on_configure_closed"))

func _on_configure_closed():
    # When configure panel is closed, show main pause controls again and free panel
    $Control.visible = true
    if configure_panel_inst and is_instance_valid(configure_panel_inst):
        configure_panel_inst.queue_free()
    configure_panel_inst = null

## Opens the weapons & items panel pointed at the enemy nearest the player.
##
## The target is resolved at press time rather than kept, because the arena
## changes while the game runs: an enemy held in a field would be freed by a
## boss or by the player's own shots, and `ConfigurePanel._get_target()` falls
## back to the player on a freed target - which would silently show the player's
## gear under an "enemy" title.
func _on_configure_enemy_pressed():
    if configure_enemy_panel_inst and is_instance_valid(configure_enemy_panel_inst):
        configure_enemy_panel_inst.visible = true
        $Control.visible = false
        return
    if not configure_menu_scene:
        push_warning("ConfigureMenu scene not found")
        return
    var enemy := _closest_enemy()
    if enemy == null:
        push_warning("PauseMenu: no enemy to configure.")
        return
    configure_enemy_panel_inst = configure_menu_scene.instantiate()
    # Before `add_child()`: the panel populates its equipped lists in `_ready()`,
    # so a target set afterwards would show the player's gear instead.
    configure_enemy_panel_inst.target_entity = enemy
    add_child(configure_enemy_panel_inst)
    configure_enemy_panel_inst.visible = true
    $Control.visible = false
    if configure_enemy_panel_inst.has_signal("closed"):
        configure_enemy_panel_inst.connect("closed", Callable(self, "_on_configure_enemy_closed"))

## The living enemy closest to the player, or null. The "enemies" group rather
## than "damageable": a dying enemy stays in the tree for its death animation but
## is out of both groups, so this cannot return a corpse.
func _closest_enemy() -> Enemy:
    var player := get_tree().get_first_node_in_group("character") as Node2D
    var closest: Enemy = null
    var closest_distance := INF
    for node in get_tree().get_nodes_in_group("enemies"):
        var enemy := node as Enemy
        if enemy == null or not (enemy is Node2D):
            continue
        # Measured from the player when there is one, so "closest" means closest
        # to the thing being shot at rather than closest to the world origin.
        if player == null:
            return enemy
        var distance := (enemy as Node2D).global_position.distance_squared_to(player.global_position)
        if distance < closest_distance:
            closest_distance = distance
            closest = enemy
    return closest

func _on_configure_enemy_closed():
    $Control.visible = true
    if configure_enemy_panel_inst and is_instance_valid(configure_enemy_panel_inst):
        configure_enemy_panel_inst.queue_free()
    configure_enemy_panel_inst = null

func _on_new_run_pressed():
    toggle_pause()
    # Start new run -> first pick character, then starter menu
    get_tree().change_scene_to_file("res://src/Scenes/menu/CharacterSelect.tscn")

func _on_main_menu_pressed():
    get_tree().paused = false
    get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _on_exit_pressed():
    get_tree().quit()
