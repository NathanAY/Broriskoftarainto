extends Control

## Dev-only fixture: the buff / debuff grid on its own, over a stub character,
## so `BuffUi` can be rendered for a visual check (see `run_scene_shot.bat`).
##
## Everything it shows is applied directly rather than played for: no damage
## pipeline, no RNG, no enemy. The two rows it cannot show in a real run - a
## debuff, and a stacked buff - are exactly the two worth looking at, which is
## why they are built here by hand.
##
## Not part of the game: nothing loads this scene.

## The buffs to show, and the event each one listens for. A `Buff` subscribes to
## its own `trigger_event`, so giving each a different one is what lets this
## fixture stack one of them three deep and leave the others at one - a single
## shared `on_hit` would stack all of them together.
const STACKED_BUFF := {"stat": "attack_speed", "mod": {"flat": 0.5}, "event": "on_hit"}
const SOLE_BUFF := {"stat": "movement_speed", "mod": {"flat": 1.5}, "event": "on_attack"}
const MULTI_STAT_BUFF := {
	"stat": "damage",
	"mod": {"flat": 4.0, "percent": 0.25},
	"event": "on_kill",
	"extra_modifiers": MULTI_STAT_EXTRA,
}
## One that sets its own name, so the display_name path sits on screen next to
## the ones that fall back to the humanized stat.
const NAMED_BUFF := {
	"stat": "critical_chance",
	"mod": {"percent": 0.25},
	"event": "on_crit",
	"display_name": "Sharpened",
	"tooltip_text": "Crits land more often.",
}

## How deep the first one stacks.
const STACKED_BUFF_TRIGGERS := 3

## A second stat for `MULTI_STAT_BUFF`: the tile has to composite both icons, and
## this is the only buff in the fixture that touches two.
const MULTI_STAT_EXTRA := {"area_radius": {"percent": 0.3}}

## Long enough that the arcs are still legible in the shot: the scene settles for
## three frames, and a 3s buff drains a visible wedge of its arc while it does.
const PREVIEW_DURATION := 30.0


func _ready() -> void:
	var character := _build_character()
	add_child(character)

	var grid: BuffUi = load("res://src/ui/BuffUi.tscn").instantiate()
	add_child(grid)
	grid.set_character(character)

	var event_manager: EventManager = character.get_node("EventManager")

	# Four buffs on four different triggers, so the row shows a 3-stack badge, two
	# tiles with no badge at all, and a composite icon - the three shapes the tile
	# has to get right.
	for spec in [STACKED_BUFF, SOLE_BUFF, MULTI_STAT_BUFF, NAMED_BUFF]:
		_add_buff(character, spec)

	_trigger(event_manager, STACKED_BUFF, STACKED_BUFF_TRIGGERS)
	_trigger(event_manager, SOLE_BUFF, 1)
	_trigger(event_manager, MULTI_STAT_BUFF, 1)
	_trigger(event_manager, NAMED_BUFF, 1)

	# One debuff, and a second instance of the same curse, so the grouping and the
	# summed badge are on screen together.
	var source := _add_debuff_source(character)
	_apply_debuff(character, source, 1.0)
	_apply_debuff(character, source, 0.6)


## Emits `spec`'s own event `count` times on the character's bus. One payload per
## event, shaped to the schema `EventContracts` requires for that name, so the
## fixture goes through `EventManager.emit_event()` exactly as the game does and
## cannot pass on a payload the real path would reject.
func _trigger(event_manager: EventManager, spec: Dictionary, count: int) -> void:
	for _i in count:
		event_manager.emit_event(str(spec["event"]), _payload_for(str(spec["event"])))


func _payload_for(event_name: String) -> Dictionary:
	match event_name:
		"on_attack":
			return {"weapon": null}
		_:
			return {"damage_context": DamageContext.new()}


func _add_buff(character: Character, spec: Dictionary) -> Buff:
	var buff: Buff = load("res://src/Systems/Items/Buffs/buff.tscn").instantiate()
	buff.trigger_event = str(spec["event"])
	buff.duration = PREVIEW_DURATION
	buff.display_name = str(spec.get("display_name", ""))
	buff.tooltip_text = str(spec.get("tooltip_text", ""))
	var modifiers: Dictionary = {str(spec["stat"]): (spec["mod"] as Dictionary).duplicate(true)}
	for extra_stat in spec.get("extra_modifiers", {}):
		modifiers[extra_stat] = (spec["extra_modifiers"][extra_stat] as Dictionary).duplicate(true)
	buff.modifiers = modifiers
	character.item_holder.add_child(buff)
	return buff


func _add_debuff_source(character: Character) -> DebuffSource:
	var source: DebuffSource = load("res://src/Systems/Items/Buffs/DebuffSource.tscn").instantiate()
	source.duration = PREVIEW_DURATION
	source.display_name = "Rust"
	source.tooltip_text = "Armour is eaten away while it lasts."
	source.modifiers = {"armor": {"flat": -10.0, "percent": -0.05}}
	character.item_holder.add_child(source)
	return source


## The debuff row's real path: `DebuffSource._on_trigger()` spawns a `Debuff` on
## the target and emits `on_debuff_added` on the *target's* bus, which for a
## debuff on the player is this character's. Called directly with a fraction of
## the source's payload so the shot shows two instances of one curse summing.
func _apply_debuff(character: Character, source: DebuffSource, share: float) -> void:
	var partial: Dictionary = {}
	for stat_name in source.modifiers:
		var values: Dictionary = (source.modifiers[stat_name] as Dictionary).duplicate(true)
		values["flat"] = float(values.get("flat", 0.0)) * share
		partial[stat_name] = values

	var debuff := Debuff.new()
	debuff.setup(source, character, partial, PREVIEW_DURATION, source,
		source.display_name, source.tooltip_text)
	character.add_child(debuff)
	character.get_node("EventManager").emit_event("on_debuff_added", {
		"debuff": debuff,
		"holder": source.get_parent().hold_owner,
		"target": character,
	})


## See `test/tools/character_ui_preview.gd` for why these placeholder children
## exist.
func _build_character() -> Character:
	var character := Character.new()
	character.name = "Character"

	var animation_player := AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	character.add_child(animation_player)

	var hitbox := Area2D.new()
	hitbox.name = "Hitbox"
	character.add_child(hitbox)

	var event_manager := EventManager.new()
	event_manager.name = "EventManager"
	character.add_child(event_manager)

	var stats := Stats.new()
	stats.name = "Stats"
	stats.event_manager = event_manager
	character.add_child(stats)

	var item_holder := ItemHolder.new()
	item_holder.name = "ItemHolder"
	character.add_child(item_holder)

	var weapon_holder := WeaponHolder.new()
	weapon_holder.name = "WeaponHolder"
	character.add_child(weapon_holder)

	return character
