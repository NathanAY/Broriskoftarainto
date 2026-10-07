extends Node

## Brings the game window to the front as the game starts, then lets it behave
## like a normal window.
##
## Running from the Godot editor works because the editor spawns the game
## directly as a child process. The godot-vscode extension spawns it as
## `{shell: true, detached: true}`, which means cmd.exe is the game's actual
## parent and the game sits in a fresh process group. Windows only lets a
## process take the foreground if it *was started by* the foreground process,
## so the game loses that exemption and `window_move_to_foreground()` - which
## calls `SetForegroundWindow` - is refused. The window stays behind VS Code.
##
## The editor's `--allow_focus_steal_pid` does not help: it maps to
## `DisplayServer.enable_for_stealing_focus()`, i.e. `AllowSetForegroundWindow()`,
## which grants the *editor* permission to take focus away from the game. It
## points the other way, and the extension does not pass it anyway.
##
## Topmost z-order is honoured regardless of those rules, so the window is held
## above everything for a frame or two and then released. Removing topmost does
## not send the window back down the stack - it keeps the z-order position it
## just gained - so this opens in front without the window staying on top.

## Frames the window is held topmost for. Only enough for the z-order change to
## be applied and drawn; any longer and the window visibly floats.
const TOPMOST_HOLD_FRAMES := 3


func _ready() -> void:
	_raise_once()


## Moves the window to the front without leaving it pinned there.
## Deliberately not awaited by callers that need the autoload to be free.
func _raise_once() -> void:
	# Wait for the first drawn frame: a raise against a window that is not yet
	# shown is dropped by Windows without complaint.
	await RenderingServer.frame_post_draw
	await raise_over(TOPMOST_HOLD_FRAMES)


## Brings the window in front and holds it above other windows for
## `hold_frames` frames, then releases it back to a normal window.
func raise_over(hold_frames: int) -> void:
	set_window_raised(true)
	for _held_frame in hold_frames:
		await get_tree().process_frame
	set_window_raised(false)


## Raises the main window above other windows, optionally pinning it there.
## No-op on the headless DisplayServer, so it is safe in tests and in a
## headless export.
static func set_window_raised(on_top: bool) -> void:
	DisplayServer.window_set_flag(
		DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,
		on_top,
		DisplayServer.MAIN_WINDOW_ID
	)
	# Ask for foreground as well: it succeeds whenever the game does hold the
	# permission, and is simply ignored when it does not.
	DisplayServer.window_move_to_foreground()