class_name RunHistory
extends RefCounted
## What the player's effects did this run, so a payout that happens off-screen
## (a bounty, a dividend, a stat gained on a kill) is still visible.
##
## `record` is the one call an effect makes: it adds the event to
## `Character.run_history` and emits `on_run_event`, which
## `RunEventSpawner` turns into floating text. Repeats of the same effect in the
## same stage merge into one entry, so a stat gained on every kill is one line
## with a count rather than hundreds. The Run history tab lists the entries.
## See `docs/systems/run_history.md`.


## Records `amount` of `what` (a stat name, or `coins`) gained from `source`
## (the effect's display name). Negative is a loss. Does nothing for a holder
## that is not the player character, so an enemy wearing the same modifier
## (the Configure enemy panel) writes nothing.
static func record(holder: Node, source: String, what: String, amount: float) -> void:
    var character := holder as Character
    if character == null or is_zero_approx(amount):
        return
    var stage := StageManager.stage_of(character)
    var entry := _find(character.run_history, stage, source, what)
    if entry.is_empty():
        character.run_history.append({"stage": stage, "source": source, "what": what, "amount": amount, "count": 1})
    else:
        entry["amount"] = float(entry["amount"]) + amount
        entry["count"] = int(entry["count"]) + 1
    if character.event_manager:
        character.event_manager.emit_event("on_run_event", {"source": source, "what": what, "amount": amount})


## "+12 Coins", "-3 Coins", "+0.5 Health".
static func amount_text(what: String, amount: float) -> String:
    var number := ItemTooltip.format_value(snappedf(absf(amount), 0.01))
    return "%s%s %s" % ["+" if amount > 0.0 else "-", number, what.capitalize()]


## One history line: "Bounty Mark: +24 Coins (x2)".
static func describe(entry: Dictionary) -> String:
    var text := "%s: %s" % [entry["source"], amount_text(entry["what"], float(entry["amount"]))]
    if int(entry["count"]) > 1:
        text += " (x%d)" % int(entry["count"])
    return text


## Replaces the children of `container` with the history, newest stage first,
## under one "Stage N" heading per stage.
static func populate(container: Container, character: Character) -> void:
    for child in container.get_children():
        container.remove_child(child)
        child.free()
    if character == null or character.run_history.is_empty():
        var empty := Label.new()
        empty.text = "Nothing has happened yet."
        container.add_child(empty)
        return
    var stages: Array = []
    for entry in character.run_history:
        if not stages.has(entry["stage"]):
            stages.append(entry["stage"])
    stages.sort()
    stages.reverse()
    for stage in stages:
        var heading := Label.new()
        heading.text = "Stage %d" % int(stage)
        heading.add_theme_color_override("font_color", Color.GOLD)
        container.add_child(heading)
        for entry in character.run_history:
            if entry["stage"] == stage:
                var line := Label.new()
                line.text = describe(entry)
                line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                if float(entry["amount"]) < 0.0:
                    line.add_theme_color_override("font_color", Color.INDIAN_RED)
                container.add_child(line)


static func _find(history: Array, stage: int, source: String, what: String) -> Dictionary:
    for entry in history:
        if entry["stage"] == stage and entry["source"] == source and entry["what"] == what:
            return entry
    return {}
