extends Interactable
class_name LoopChoicePortal

## A world portal standing for one answer to the end-of-run question. It only
## reports which answer it is; `StageManager` owns what that means for the run.
##
## Two of these are spawned past `StageManager.FINAL_BOSS_LOOP`: one for the
## final boss, one for another loop. Picking either frees both.

signal chosen(choice: Choice)

enum Choice { FINAL_BOSS, EXTRA_LOOP }

@export var choice: Choice = Choice.FINAL_BOSS
@export var label_text: String = "Final boss"
## Tints the shared portal sprite so the two portals read apart at a glance.
@export var tint: Color = Color.WHITE

func _ready():
    modulate = tint
    super()

func _populate_menu(menu: Control):
    var label: Label = menu.get_node("Description/Label")
    label.text = label_text

    var go_button: Button = menu.get_node("Button")
    go_button.text = "'Enter' Enter"

    # The answer is forced: no "Leave" option, so the second button stays hidden.
    var cancel_button: Button = menu.get_node("Button2")
    cancel_button.visible = false

func default_action():
    chosen.emit(choice)

## Tab (`ui_focus_next`) routes here. It must not free the portal: the run is
## waiting on this answer, and the portals only go away once one is picked.
func cancel_action():
    pass
