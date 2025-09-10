# TowerUI.gd
extends Control

@export var tower: Node  # assign the tower instance in the inspector

@onready var stats_container: GridContainer = $PanelContainer/VBoxContainer/GridContainer
@onready var items_container: VBoxContainer = $PanelContainer/VBoxContainer/Items

var stats_node: Stats = null
var item_holder: Node = null
var value_labels: Dictionary = {}  # stat_name -> Label

func _ready():
    if not tower:
        push_error("TowerUI: No tower assigned! Set the 'tower' export or call set_tower(tower).")
        return

    stats_node = tower.get_node_or_null("Stats")
    item_holder = tower.get_node_or_null("ItemHolder")
    var em = tower.get_node_or_null("EventManager")

    # Setup stats UI and listeners
    if stats_node:
        _update_stats()
        if stats_node.has_signal("stat_changed"):
            stats_node.connect("stat_changed", Callable(self, "_on_stat_changed"))
        # also subscribe to tower event manager if present (emits on_stat_changes)
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
        value_label.text = str(name_label, ": ", val)
        value_label.name = "value_" + str(stat_name)
        stats_container.add_child(value_label)

        value_labels[stat_name] = value_label

# Called when Stats emits its signal (stat_changed(stat_name, new_value))
func _on_stat_changed(event) -> void:
    var stat_name: String = event["stat_name"]
    var new_value: float = event["final_value"]
    var lbl = value_labels.get(stat_name, null)
    if lbl:
        lbl.text = str(str(stat_name).capitalize(), ": ", new_value)
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
    # entity is the owner of the item; only update UI if it's the current tower
    if entity != tower:
        return
    var l = Label.new()
    l.text = _item_display_name(item)
    items_container.add_child(l)

func _on_item_removed(args: Array) -> void:
    var entity = args[0]
    var item = args[1]
    if entity != tower:
        return
    _update_items()

func _item_display_name(item: Resource) -> String:
    # Prefer Item.name, fallback to resource_name or to_class string
    if typeof(item) == TYPE_OBJECT and item is Item:
        return str(item.name)
    if "resource_name" in item:
        return str(item.resource_name)
    return str(item)

# --- helper to set tower at runtime ----------------------------------------

func set_tower(t: Node) -> void:
    tower = t
    _ready()  # re-init (simple approach). If you call this at runtime you may want to disconnect previous connections first.
