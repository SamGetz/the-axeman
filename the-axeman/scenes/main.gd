extends Node
## FILE: res://scenes/main.gd
## ATTACHES TO: Main (Node), the root of res://scenes/main.tscn.
##
## M2 — main scene shell. Owns the A10 2D/3D mode switch and nothing else:
##   2D mode: Action_Viewport stops rendering, 3D_World_Root stops processing.
##   3D mode (on EventBus.minigame_entered): both restored.
## No gameplay logic lives here. Gameplay UI goes in UI_Overlay (A9), never
## UI_Canvas.
##
## Temp debug keys (see the block at the bottom): M enters/leaves the 3D mode.

@onready var _action_viewport: SubViewport = $"UI_Canvas/SubViewportContainer/Action_Viewport"
@onready var _world_root: Node3D = $"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root"


func _ready() -> void:
	EventBus.minigame_entered.connect(_on_minigame_entered)
	EventBus.minigame_exited.connect(_on_minigame_exited)
	_enter_2d_mode()

	# Boot the player's yard back up. Autoloads have already run their _ready by
	# now, so the registry is parsed and both serialisers are safe to call.
	var result := SaveSystem.load_or_start_fresh()
	if result == SaveSystem.LoadResult.OK:
		print("Main: save loaded — %d cash, %d wood chopped lifetime." % [
			GameState.get_cash(), GameState.get_lifetime_wood_chopped(),
		])

	# Godot tears the window down the moment it is closed unless told otherwise,
	# which would drop everything earned since the last save.
	get_tree().auto_accept_quit = false


## Save on the way out. NOTIFICATION_WM_CLOSE_REQUEST is the only hook that fires
## early enough to still see live state — _exit_tree and PREDELETE run after the
## tree has begun coming apart.
##
## Quitting is UNCONDITIONAL: if the save fails the player is told, but the window
## still closes. A game that refuses to shut down is a worse bug than a lost
## session.
##
## OPEN, and Sam's call: this saves on quit ONLY. A crash or a power cut still
## costs the session. Periodic autosave needs a cadence (every N seconds? on each
## completed log? on each sale?), which is a feel decision, not a default to
## invent here.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	if not SaveSystem.save_game():
		push_error("Main: the save failed on quit — this session's progress is lost.")
	get_tree().quit()


func _on_minigame_entered(_biome: Enums.Biome) -> void:
	_enter_3d_mode()


func _on_minigame_exited() -> void:
	_enter_2d_mode()


func _enter_2d_mode() -> void:
	# A10: while in 2D management mode the 3D world neither renders nor thinks.
	_action_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_world_root.process_mode = Node.PROCESS_MODE_DISABLED


func _enter_3d_mode() -> void:
	_action_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_world_root.process_mode = Node.PROCESS_MODE_INHERIT


# ---------------------------------------------------------------------------
# M2 TEMPORARY DEBUG — remove when M7 provides the real minigame entry flow.
# Press M to toggle between 2D and 3D mode so the pixel pipeline can be
# eyeballed from the main scene. Uses the real EventBus signals (A7) so the
# production path is what gets exercised.
#
# The T key that swapped between the chopping block and the tree-felling scene
# went with the tree game (2026-08-01 pivot); the chopping mini-game is now the
# only thing under 3D_World_Root and it is instanced in main.tscn.
# ---------------------------------------------------------------------------
var _debug_in_minigame := false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_M:
		if _debug_in_minigame:
			EventBus.minigame_exited.emit()
		else:
			EventBus.minigame_entered.emit(Enums.Biome.PINE_FOREST)
		_debug_in_minigame = not _debug_in_minigame
