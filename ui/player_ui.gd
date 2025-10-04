# CharacterUI.gd
extends Control

@export var character: Character  # assign the character instance in the inspector
@export var stage_manager: StageManager

@onready var stats_container: GridContainer = $PanelContainer/VBoxContainer/GridContainer
@onready var items_container: VBoxContainer = $PanelContainer/VBoxContainer/Items
@onready var stageTimer: Label = $StageTimer

var stats_node: Stats = null
var item_holder: Node = null
var value_labels: Dictionary = {}  # stat_name -> Label
var _show_stage_scaleing: bool = false

func _process(delta: float) -> void:
    var current_staget = "Loop " + str(stage_manager.current_loop)
    var stage_time_elapsed = stage_manager.stage_time_elapsed
    var stage_duration = str(int(stage_manager.stage_duration - stage_time_elapsed))
    if _show_stage_scaleing:
        var health_growth_per_stage = " enemy health +" + str(stage_manager.enemy_spawner.health_growth_per_loop * (stage_manager.enemy_spawner.current_loop))
        var damage_growth_per_stage = " damage +" + str(stage_manager.enemy_spawner.damage_growth_per_loop * (stage_manager.enemy_spawner.current_loop))
        stageTimer.text = current_staget + " Survive " + stage_duration + " scaling " + health_growth_per_stage + damage_growth_per_stage
    else:
        stageTimer.text = current_staget + " Survive " + stage_duration

func _ready():
    if not character:
        push_error("CharacterUI: No character assigned! Set the 'character' export or call set_character(character).")
        return

    stats_node = character.get_node_or_null("Stats")
    item_holder = character.get_node_or_null("ItemHolder")
    var em = character.get_node_or_null("EventManager")

    # Setup stats UI and listeners
    if stats_node:
        _update_stats()
        if stats_node.has_signal("stat_changed"):
            stats_node.connect("stat_changed", Callable(self, "_on_stat_changed"))
        # also subscribe to character event manager if present (emits on_stat_changes)
        if em:
            em.subscribe("on_stat_changes", Callable(self, "_on_stat_changed_event"))

    # Setup items UI and listeners
    if item_holder:
        _update_items()
        if em:
            em.subscribe("on_item_added", Callable(self, "_on_item_added"))
            em.subscribe("on_item_removed", Callable(self, "_on_item_removed"))

# --- utilities ---------------------------------------------------------------

func _clear_container(container: Node) -> void:
    # safe way to remove all children
    for child in container.get_children():
        child.queue_free()

# --- stats UI ---------------------------------------------------------------

func _update_stats() -> void:
    _clear_container(stats_container)
    value_labels.clear()
    if not stats_node:
        return

    # iterate over base stat keys (Stats.gd stores a `stats` dict)
    if not stats_node.stats:
        return

    for stat_name in stats_node.stats.keys():
        var value_label = Label.new()
        var name_label = str(stat_name).capitalize()
        
        var val = stats_node.get_stat(stat_name)
        value_label.text = "%s: %.2f" % [name_label, val]
        value_label.name = "value_" + str(stat_name)
        stats_container.add_child(value_label)

        value_labels[stat_name] = value_label

# Called when Stats emits its signal (stat_changed(stat_name, new_value))
func _on_stat_changed(event) -> void:
    var stat_name: String = event["stat_name"]
    var new_value: float = event["final_value"]
    var lbl = value_labels.get(stat_name, null)
    if lbl:
        lbl.text = "%s: %.2f" % [stat_name, new_value]
    else:
        # new stat not present in UI — rebuild full list
        _update_stats()

# Called when EventManager emits on_stat_changes(stat_name, value)
# LocalEventManager.callv passes positional args, so this function signature matches
func _on_stat_changed_event(event) -> void:
    _on_stat_changed(event)

# --- items UI ---------------------------------------------------------------

func _update_items() -> void:
    _clear_container(items_container)
    if not item_holder:
        return

    if not item_holder.items:
        return

    for item in item_holder.items:
        var l = Label.new()
        l.text = _item_display_name(item)
        items_container.add_child(l)

func _on_item_added(event: Dictionary) -> void:
    var entity = event.get("hold_owner")
    var item = event.get("item")
    # entity is the owner of the item; only update UI if it's the current character
    if entity != character:
        return
    var l = Label.new()
    l.text = _item_display_name(item)
    items_container.add_child(l)
    #_update_items()

func _on_item_removed(event: Dictionary) -> void:
    var entity = event.get("hold_owner")
    var item = event.get("item")
    if entity != character:
        return  
    _update_items()

func _item_display_name(item: Resource) -> String:
    # Prefer Item.name, fallback to resource_name or to_class string
    if typeof(item) == TYPE_OBJECT and item is Item:
        return str(item.name)
    if "resource_name" in item:
        return str(item.resource_name)
    return str(item)

# --- helper to set character at runtime ----------------------------------------

func set_character(t: Node) -> void:
    character = t
    _ready()  # re-init (simple approach). If you call this at runtime you may want to disconnect previous connections first.
