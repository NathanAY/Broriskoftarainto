# Shows the player's active buffs (top row) and debuffs (bottom row) as icon
# tiles, and nothing else: the full stat change, the trigger and the stat's own
# explanation are hover-only, in the `TooltipUi` this scene owns.
#
# Tiles are keyed by the live effect node, never by a stringified modifier dict,
# so two distinct buffs with identical modifiers stay two tiles and a buff whose
# modifiers change stays one. Debuffs do not stack at their source - every
# trigger spawns a separate `Debuff` node - so they group by `Debuff.source` and
# the tile's badge counts the instances.
class_name BuffUi
extends Control

const TILE_SCENE: PackedScene = preload("res://src/ui/BuffTile.tscn")
## Gap between tiles. Applied here rather than trusted from the scene literals,
## so the row spacing has one owner.
const TILE_SEPARATION := 6

@onready var buffs_row: HBoxContainer = $Margin/VBox/BuffsRow
@onready var debuffs_row: HBoxContainer = $Margin/VBox/DebuffsRow
## A sibling of the rows rather than a third row: the tooltip positions itself
## against the mouse, so leaving it inside the `VBoxContainer` would only have it
## laid out - and reserving vertical space for a node that floats over the game.
@onready var tooltip: TooltipUi = $Tooltip

var character: Node = null

## key -> { "tile": BuffTile, "entry": BuffEntry, "nodes": Array[Node] }
## For a buff, `nodes` holds the single `Buff`. For a debuff, it holds every
## `Debuff` spawned by the tile's `DebuffSource`.
var _tiles: Dictionary = {}

## The bus we subscribed to, so `set_character()` can move rather than stack a
## second set of listeners on top of the first.
var _subscribed_to: EventManager = null


func _ready() -> void:
    buffs_row.add_theme_constant_override("separation", TILE_SEPARATION)
    debuffs_row.add_theme_constant_override("separation", TILE_SEPARATION)
    if character == null:
        # Both real hosts (`PlayerUI` / `CharacterUI`) expose a `character`, and
        # the grid falls back to the global for a scene that is instanced on its
        # own. Checked rather than dereferenced: a parent without the field must
        # fall through to the global, not raise.
        var host := get_parent()
        if host != null and "character" in host:
            character = host.get("character")
    if character == null:
        character = GlobalGameState.current_character
    if character == null:
        push_error("BuffUI: No character assigned! Use set_character().")
        return
    _subscribe()
    _refresh_row_visibility()


## Points the grid at a different character. Unsubscribes first: calling
## `_ready()` again re-subscribed without unsubscribing, so every listener landed
## twice and one buff produced two tiles.
func set_character(new_character: Node) -> void:
    if new_character == character and _subscribed_to != null:
        return
    _unsubscribe()
    clear()
    character = new_character
    if character == null:
        return
    _subscribe()


func _subscribe() -> void:
    var em: EventManager = character.get_node_or_null("EventManager")
    if em == null:
        push_warning("BuffUI: character has no EventManager")
        return
    _subscribed_to = em
    em.subscribe("on_buff_added", Callable(self, "_on_buff_added"))
    em.subscribe("on_buff_removed", Callable(self, "_on_buff_removed"))
    em.subscribe("on_debuff_added", Callable(self, "_on_debuff_added"))
    em.subscribe("on_debuff_removed", Callable(self, "_on_debuff_removed"))


func _unsubscribe() -> void:
    if _subscribed_to == null:
        return
    _subscribed_to.unsubscribe("on_buff_added", Callable(self, "_on_buff_added"))
    _subscribed_to.unsubscribe("on_buff_removed", Callable(self, "_on_buff_removed"))
    _subscribed_to.unsubscribe("on_debuff_added", Callable(self, "_on_debuff_added"))
    _subscribed_to.unsubscribe("on_debuff_removed", Callable(self, "_on_debuff_removed"))
    _subscribed_to = null


# --- event handlers ------------------------------------------------------------

func _on_buff_added(event: Dictionary) -> void:
    var buff: Buff = event.get("buff")
    if buff == null or not is_instance_valid(buff):
        return
    var key := buff.get_instance_id()
    if not _tiles.has(key):
        _add_tile(key, [buff], false)
    _refresh(key)


func _on_buff_removed(event: Dictionary) -> void:
    var buff: Buff = event.get("buff")
    if buff == null:
        return
    # One `Buff` node is one tile and its own stack count is the badge, so a
    # removal only matters when the last stack has gone.
    _refresh(buff.get_instance_id())


func _on_debuff_added(event: Dictionary) -> void:
    var debuff: Debuff = event.get("debuff")
    if debuff == null or not is_instance_valid(debuff):
        return
    var key := _debuff_key(debuff)
    if not _tiles.has(key):
        _add_tile(key, [debuff], true)
    else:
        (_tiles[key]["nodes"] as Array).append(debuff)
    _refresh(key)


func _on_debuff_removed(event: Dictionary) -> void:
    var debuff: Debuff = event.get("debuff")
    if debuff == null:
        return
    var key := _debuff_key(debuff)
    if not _tiles.has(key):
        return
    var nodes: Array = _tiles[key]["nodes"]
    nodes.erase(debuff)
    if nodes.is_empty():
        _remove_tile(key)
        return
    _refresh(key)


## Two debuffs of one kind are one tile, so the grouping key is the
## `DebuffSource` that spawned them. A debuff with no source (a test or a fixture
## that called `setup()` directly) is its own tile rather than being merged with
# every other sourceless debuff on the target.
func _debuff_key(debuff: Debuff) -> int:
    if debuff.source != null and is_instance_valid(debuff.source):
        return debuff.source.get_instance_id()
    return debuff.get_instance_id()


# --- tiles ---------------------------------------------------------------------

func _add_tile(key: int, nodes: Array, is_debuff: bool) -> void:
    var tile: BuffTile = TILE_SCENE.instantiate()
    var row := debuffs_row if is_debuff else buffs_row
    row.add_child(tile)
    tile.mouse_entered.connect(func() -> void: tile.set_hovered(true))
    tile.mouse_exited.connect(func() -> void: tile.set_hovered(false))

    var entry := BuffEntry.new()
    entry.is_debuff = is_debuff
    _tiles[key] = {"tile": tile, "entry": entry, "nodes": nodes}
    # Bound once, here, against the live `entry` object. `_fill_entry()` mutates
    # that object in place rather than replacing it, so the closure always reads
    # the counts as they are when the mouse arrives - and re-binding per frame
    # would reconnect the hover signals every frame.
    tooltip.bind_to_row_buff(tile, entry)
    _fill_entry(key)
    _refresh_row_visibility()


## Drops a tile's record and frees the tile. `immediate` frees it now instead of
## at the end of the frame, which only `clear()` uses: a queued tile is still a
## child, so a character swap would leave the previous character's buff on screen
## for one frame. The per-frame path keeps `queue_free()` because it can run from
## inside the tile's own signal handling.
func _remove_tile(key: int, immediate: bool = false) -> void:
    if not _tiles.has(key):
        return
    var tile: BuffTile = _tiles[key]["tile"]
    _tiles.erase(key)
    if is_instance_valid(tile):
        if immediate:
            tile.free()
        else:
            tile.queue_free()
    _refresh_row_visibility()


func _fill_entry(key: int) -> void:
    var record: Dictionary = _tiles[key]
    var nodes: Array = record["nodes"]
    var entry: BuffEntry = record["entry"]

    _collect(nodes, entry)

    if entry.stack_count <= 0:
        _remove_tile(key)
        return

    (record["tile"] as BuffTile).set_entry(entry)


## Reads the current numbers off the live nodes into `entry`, in place.
func _collect(nodes: Array, entry: BuffEntry) -> void:
    var live: Array = []
    for node in nodes:
        if is_instance_valid(node):
            live.append(node)
    nodes.assign(live)

    var first: Node = live[0] if not live.is_empty() else null
    entry.key = first

    if first is Buff:
        var buff: Buff = first
        # One `Buff` node is one tile, so the count is the node's own stack count
        # and not how many nodes are in the list - there is only ever one.
        entry.stack_count = buff.stack_count()
        # A buff applies the same payload once per stack, so the tile reports the
        # multiplied total: three stacks of +0.5 moved attack_speed by 1.5, and a
        # tooltip reading 0.5 would disagree with the stat the player watches.
        entry.modifiers = BuffEntry.scaled_modifiers(buff.modifiers, entry.stack_count)
        entry.name = buff.display_name
        entry.max_stacks = buff.max_stacks
        entry.duration = buff.duration
        entry.remaining = buff.remaining_time()
        entry.trigger = buff.trigger_event
        entry.tooltip_text = buff.tooltip_text
        return

    # Debuffs group by source, so the tile's count is how many instances are live
    # and the total is the sum of their modifiers: what the stat actually moved
    # by, not one curse's worth.
    entry.stack_count = live.size()
    var per_stack: Array = []
    var soonest := INF
    for debuff in live:
        per_stack.append((debuff as Debuff).modifiers)
        soonest = minf(soonest, (debuff as Debuff).remaining_time())
    entry.modifiers = BuffEntry.total_modifiers(per_stack)
    entry.name = (first as Debuff).display_name
    entry.max_stacks = 0
    entry.duration = (first as Debuff).duration
    entry.remaining = 0.0 if soonest == INF else soonest
    entry.trigger = first.source.trigger_event if first.source != null else ""
    entry.tooltip_text = (first as Debuff).tooltip_text


func _refresh(key: int) -> void:
    if not _tiles.has(key):
        return
    _fill_entry(key)


func _process(_delta: float) -> void:
    # Two numbers per tile, and a redraw. The old readout re-formatted every
    # label every frame, which is ten `%.1f` builds a frame for text that changes
    # visibly about twice a second; nothing here builds a string.
    for key in _tiles.keys():
        var record: Dictionary = _tiles[key]
        var nodes: Array = record["nodes"]
        # A `Debuff` frees itself on expiry, and a holder freed outright (a
        # character swap) takes its effects with it without emitting anything, so
        # a tile can be left pointing at a freed node.
        if not _nodes_alive(nodes):
            _remove_tile(key)
            continue
        var tile: BuffTile = record["tile"]
        if not is_instance_valid(tile):
            _remove_tile(key)
            continue
        _retime(record["entry"], nodes)
        tile.tick()


## The per-frame half of `_collect()`: the stack count and the countdown, and
## nothing else. The identity fields only move when the effect itself does, which
## an event reports, so rebuilding the icon and the summed modifiers every frame
## would be pure waste.
func _retime(entry: BuffEntry, nodes: Array) -> void:
    var first: Node = nodes[0]
    if first is Buff:
        entry.stack_count = (first as Buff).stack_count()
        entry.remaining = (first as Buff).remaining_time()
        return
    entry.stack_count = nodes.size()
    var soonest := INF
    for debuff in nodes:
        soonest = minf(soonest, (debuff as Debuff).remaining_time())
    entry.remaining = 0.0 if soonest == INF else soonest


func _nodes_alive(nodes: Array) -> bool:
    for node in nodes:
        if is_instance_valid(node):
            return true
    return false


## An empty row reserves no gap. Both rows stay in the tree either way, so the
## buff row never moves when the first debuff lands.
func _refresh_row_visibility() -> void:
    buffs_row.visible = buffs_row.get_child_count() > 0
    debuffs_row.visible = debuffs_row.get_child_count() > 0


## Frees both rows' tiles. The old `_clear()` only walked the buff row, so
## debuff tiles survived a character swap and kept hovering for a character that
## was no longer there.
func clear() -> void:
    # Immediate, not queued: this is the character-swap path, and a queued tile is
    # still a child until the end of the frame, so the old character's buffs would
    # stay on screen for a frame after they stopped being true.
    for key in _tiles.keys():
        _remove_tile(key, true)
    _tiles.clear()
    if is_node_ready():
        _refresh_row_visibility()


## The tiles currently on screen, for tests and for a host that wants to inspect
## what the grid decided.
func tile_for(key: int) -> BuffTile:
    if not _tiles.has(key):
        return null
    return _tiles[key]["tile"]


func active_tile_count() -> int:
    return _tiles.size()
