extends CanvasLayer

@onready var resume_button: Button = $Control/VBoxContainer/ResumeButton
@onready var restart_button: Button = $Control/VBoxContainer/RestartButton
@onready var new_run_button: Button = $Control/VBoxContainer/NewRunButton
@onready var options_button: Button = $Control/VBoxContainer/OptionsButton
@onready var exit_button: Button = $Control/VBoxContainer/ExitButton

@onready var options_menu: CanvasLayer = $OptionsMenu
var configure_panel_inst = null
var configure_menu_scene: PackedScene = null

var window_modes := [
    Vector2i(1280, 720),
    Vector2i(1920, 1080),
    "fullscreen"
]
var current_index := 0

func _ready():
    resume_button.pressed.connect(_on_resume_pressed)
    restart_button.pressed.connect(_on_restart_pressed)
    new_run_button.pressed.connect(_on_new_run_pressed)
    options_button.pressed.connect(_on_options_pressed)
    # Add Configure button dynamically so the scene file doesn't need editing
    var cfg_btn = Button.new()
    cfg_btn.text = "Configure"
    cfg_btn.pressed.connect(_on_configure_pressed)
    $Control/VBoxContainer.add_child(cfg_btn)
    # preload ConfigureMenu scene so it behaves like options_menu
    configure_menu_scene = load("res://Scenes/menu/ConfigureMenu.tscn")
    exit_button.pressed.connect(_on_exit_pressed)
    options_menu.visible = false

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

func _on_new_run_pressed():
    toggle_pause()
    # Start new run -> first pick character, then starter menu
    get_tree().change_scene_to_file("res://Scenes/menu/CharacterSelect.tscn")

func _on_exit_pressed():
    get_tree().quit()
