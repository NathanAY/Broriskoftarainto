extends Interactable
class_name Portal
## Shared base of the world portals (`ShopPortal`, `StageChoicePortal`).
##
## Pressing Enter does not act at once: the portal pulls the player to its
## centre, spins them down into the hole while its aura winds up, flashes, and
## only then runs `_on_entered()`. The player pops back out afterwards — on the
## character's own tween, so it survives the portal being freed and, for the
## shop, waits out the pause and plays as the shop closes.

## Seconds the player slides to the portal's centre.
const PULL_DURATION := 0.3
## Seconds the player spins down into the hole.
const SINK_DURATION := 0.5
## Total time from Enter to `_on_entered()`.
const ENTRY_DURATION := PULL_DURATION + SINK_DURATION
## Seconds the player takes to pop back out.
const POP_DURATION := 0.35
## How small the player gets before vanishing.
const SINK_SCALE := 0.1

## On-screen scale of the interaction menu. The menu is a child, so it would
## otherwise grow with the portal art; this is the size it had at the old 1.5x.
const MENU_SCALE := 1.5

## True from Enter until `_on_entered()` has run. A second Enter is ignored.
var is_entering := false

var aura: PortalAura:
	get:
		return get_node_or_null("Aura") as PortalAura


func _ready():
	super()
	interaction_menu.scale = Vector2.ONE * (MENU_SCALE / scale.x)


func default_action():
	if is_entering:
		return
	is_entering = true
	disable_interaction()
	var character := get_tree().current_scene.get_node_or_null("Character") as Node2D
	var full_scale := character.scale if character else Vector2.ONE
	if aura:
		aura.surge(ENTRY_DURATION)
	_on_entry_started()
	await _sink(character)
	var tint := aura.color * modulate if aura else modulate
	PortalAura.flash(get_parent(), global_position, _world_radius(), tint)
	_on_entered()
	if character:
		_pop_out(character, full_scale)


## Override: the portal's real action, run once the entry animation is done.
func _on_entered() -> void:
	pass


## Override: runs as the entry animation starts, for anything that should be
## drawn into the portal alongside the player.
func _on_entry_started() -> void:
	pass


func _world_radius() -> float:
	return (aura.radius if aura else PortalAura.FALLBACK_RADIUS) * global_scale.x


func _sink(character: Node2D) -> void:
	var tween := create_tween()
	if character == null:
		tween.tween_interval(ENTRY_DURATION)
		await tween.finished
		return
	_set_movement_enabled(character, false)
	var start_scale := character.scale
	tween.tween_property(character, "global_position", global_position, PULL_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(character, "scale", start_scale * SINK_SCALE, SINK_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(character, "modulate:a", 0.0, SINK_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var body := character.get_node_or_null("Node2D") as Node2D
	if body:
		# Two full turns, so the body ends at its starting angle with no snap.
		tween.parallel().tween_property(body, "rotation", body.rotation + TAU * 2.0, SINK_DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished


static func _pop_out(character: Node2D, full_scale: Vector2) -> void:
	var body := character.get_node_or_null("Node2D") as Node2D
	if body:
		body.rotation = wrapf(body.rotation, -PI, PI)
	var tween := character.create_tween()
	tween.tween_property(character, "scale", full_scale, POP_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(character, "modulate:a", 1.0, POP_DURATION * 0.5)
	tween.tween_callback(_set_movement_enabled.bind(character, true))


static func _set_movement_enabled(character: Node, enabled: bool) -> void:
	var movement := character.get_node_or_null("Movement")
	if movement:
		movement.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
