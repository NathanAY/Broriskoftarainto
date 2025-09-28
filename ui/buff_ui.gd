#Shows buffs and debuffs
extends Control

var character: Node  # assigned from CharacterUI

@onready var buffs_container: HBoxContainer = $PanelContainer/HBoxContainer
@onready var debuffs_container: HBoxContainer = $PanelContainer2/HBoxContainer

# buff_id -> { "buffs": Array[Buff], "label": Label }
var active_buffs: Dictionary = {}
var active_debuffs: Dictionary = {}

func _ready():
    character = get_parent().character
    if not character:
        push_error("BuffUI: No character assigned! Use set_character().")
        return
    
    var em = character.get_node_or_null("EventManager")
    if not em:
        push_warning("BuffUI: character has no EventManager")
        return
    
    em.subscribe("on_buff_added", Callable(self, "_on_buff_added"))
    em.subscribe("on_buff_removed", Callable(self, "_on_buff_removed"))    
    em.subscribe("on_debuff_added", Callable(self, "_on_debuff_added"))
    em.subscribe("on_debuff_removed", Callable(self, "_on_debuff_removed"))

# --- event handlers ------------------------------------------------

func _on_buff_added(event: Dictionary):
    var buff: Buff = event.get("buff")
    if not buff:
        return

    var id = _get_buff_id(buff)

    if active_buffs.has(id):
        active_buffs[id]["buffs"].append(buff)
    else:
        var l = Label.new()
        buffs_container.add_child(l)
        active_buffs[id] = {"buffs": [buff], "label": l}

    _update_label(id)

func _on_buff_removed(event: Dictionary):
    var buff: Buff = event.get("buff")
    if not buff:
        return
    
    var id = _get_buff_id(buff)
    if not active_buffs.has(id):
        return
    
    active_buffs[id]["buffs"].erase(buff)
    
    if active_buffs[id]["buffs"].is_empty():
        var lbl: Label = active_buffs[id]["label"]
        lbl.queue_free()
        active_buffs.erase(id)
    else:
        _update_label(id)

func _on_debuff_added(event: Dictionary):
    var buff: Debuff = event.get("debuff")
    if not buff:
        return

    var id = _get_buff_id(buff)

    if active_debuffs.has(id):
        active_debuffs[id]["debuffs"].append(buff)
    else:
        var l = Label.new()
        debuffs_container.add_child(l)
        active_debuffs[id] = {"debuffs": [buff], "label": l}

    _update_label_debuff(id)

func _on_debuff_removed(event: Dictionary):
    var debuff: Debuff = event.get("debuff")
    if not debuff:
        return
    
    var id = _get_buff_id(debuff)
    if not active_debuffs.has(id):
        return
    
    active_debuffs[id]["debuffs"].erase(debuff)
    
    if active_debuffs[id]["debuffs"].is_empty():
        var lbl: Label = active_debuffs[id]["label"]
        lbl.queue_free()
        active_debuffs.erase(id)
    else:
        _update_label_debuff(id)
# --- update loop ---------------------------------------------------

func _process(delta: float) -> void:
    for id in active_buffs.keys():
        _update_label(id)
    for id in active_debuffs.keys():
        _update_label_debuff(id)    

func _update_label(id: String):
    var info = active_buffs[id]
    var buffs: Array = info["buffs"]
    var lbl: Label = info["label"]

    if buffs.is_empty():
        return

    var stack_text = " x%d" % buffs.size() if buffs.size() > 1 else ""
    # All buffs of same type share modifiers, so use first
    var mods_text = _format_modifiers(buffs[0].modifiers)

    # Remaining time = shortest among stacks
    var min_time = INF
    for b in buffs:
        var timers = b.get_children().filter(func(c): return c is Timer)
        if timers:
            min_time = min(min_time, timers[timers.size() - 1].time_left)
    var remaining = min_time if min_time < INF else buffs[0].duration
    lbl.text = "%s %s (%.1fs)" % [mods_text, stack_text, remaining]

func _update_label_debuff(id: String):
    var info = active_debuffs[id]
    var debuffs: Array = info["debuffs"]
    var lbl: Label = info["label"]

    # ✅ Remove invalid/freed debuffs
    debuffs = debuffs.filter(func(b): return is_instance_valid(b))

    # Save cleaned list back
    info["debuffs"] = debuffs
    active_debuffs[id] = info

    if debuffs.is_empty():
        lbl.text = "" # or hide it
        return

    var stack_text = " x%d" % debuffs.size() if debuffs.size() > 1 else ""
    # All buffs of same type share modifiers, so use first
    var mods_text = _format_modifiers(debuffs[0].modifiers)

    # Remaining time = shortest among stacks
    var min_time = INF
    for b in debuffs:
        var timers = b.get_children().filter(func(c): return c is Timer)
        if timers:
            min_time = min(min_time, timers[timers.size() - 1].time_left)

    var remaining = min_time if min_time < INF else debuffs[0].duration
    lbl.text = "%s %s (%.1fs)" % [mods_text, stack_text, remaining]


func _update_debuff_label(id: String):
    var info = active_buffs[id]
    var debuffs: Array = info["debuffs"]
    var lbl: Label = info["label"]

    if debuffs.is_empty():
        return

    var stack_text = " x%d" % debuffs.size() if debuffs.size() > 1 else ""
    # All buffs of same type share modifiers, so use first
    var mods_text = _format_modifiers(debuffs[0].modifiers)

    # Remaining time = shortest among stacks
    var min_time = INF
    for b in debuffs:
        var timers = b.get_children().filter(func(c): return c is Timer)
        if timers:
            min_time = min(min_time, timers[timers.size() - 1].time_left)

    
    var remaining = min_time if min_time < INF else debuffs[0].duration

    lbl.text = "%s%s (%.1fs)" % [mods_text, stack_text, remaining]

# --- helpers -------------------------------------------------------

func _clear():
    for c in buffs_container.get_children():
        c.queue_free()
    active_buffs.clear()

func _get_buff_id(buff) -> String:
    var keys = buff.modifiers.keys()
    keys.sort()
    var parts = []
    for stat_name in keys:
        var entry = buff.modifiers[stat_name]
        var flat = entry.get("flat", 0)
        var percent = entry.get("percent", 0.0)
        parts.append("%s:%s:%s" % [stat_name, flat, percent])
    return "|".join(parts)

func _format_modifiers(modifiers: Dictionary) -> String:
    var parts: Array[String] = []
    for stat_name in modifiers.keys():
        var entry: Dictionary = modifiers[stat_name]
        var flat = entry.get("flat", 0)
        var percent = entry.get("percent", 0.0)

        var text = stat_name.capitalize()
        var segments: Array[String] = []

        if flat != 0:
            segments.append("%s" % flat)
        if percent != 0:
            segments.append("%d%%" % [int(percent * 100)])

        if not segments.is_empty():
            text += " " + " ".join(segments)

        parts.append(text)

    return ", ".join(parts)
