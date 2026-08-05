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
## The chopping game is now the default and only production view. A10's mode
## switch remains available for future transitions, but management opens as HUD
## panels over the live chopping scene instead of entering a separate 2D mode.

var _save_queued := false

@onready var _action_viewport: SubViewport = $"UI_Canvas/SubViewportContainer/Action_Viewport"
@onready var _world_root: Node3D = $"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root"
@onready var _splitter_runtime: MechanicalSplitterRuntime = $"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/Chopping_Minigame/MechanicalSplitterRuntime"
@onready var _yard_hud: Control = $UI_Overlay/YardHUD


func _ready() -> void:
	EventBus.minigame_entered.connect(_on_minigame_entered)
	EventBus.minigame_exited.connect(_on_minigame_exited)
	_enter_3d_mode()

	# Boot the player's yard back up. Autoloads have already run their _ready by
	# now, so the registry is parsed and both serialisers are safe to call.
	var result := SaveSystem.load_or_start_fresh()
	if result == SaveSystem.LoadResult.OK:
		print("Main: save loaded — %d cash, %d wood chopped lifetime." % [
			GameState.get_cash(), GameState.get_lifetime_wood_chopped(),
		])
	_yard_hud.bind_splitter_runtime(_splitter_runtime)

	# Autosave whenever owned stock OR progression moves. Connected AFTER the load
	# on purpose: every serialiser emits as it restores fields, so connecting any
	# of these earlier would make loading immediately rewrite what was just read.
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	GameState.cash_changed.connect(_queue_autosave.unbind(1))
	GameState.yard_pile_changed.connect(_queue_autosave.unbind(1))
	GameState.selected_species_changed.connect(_queue_autosave.unbind(1))
	GameState.xp_changed.connect(_queue_autosave.unbind(1))
	GameState.skill_level_changed.connect(_queue_autosave.unbind(2))
	GameState.species_purchased.connect(_queue_autosave.unbind(1))
	GameState.species_mastery_changed.connect(_queue_autosave.unbind(2))
	GameState.splitter_assignment_changed.connect(_queue_autosave.unbind(1))
	GameState.order_state_changed.connect(_queue_autosave)

	# Godot tears the window down the moment it is closed unless told otherwise,
	# which would drop everything earned since the last save.
	get_tree().auto_accept_quit = false


## ---------------------------------------------------------------- autosave
## Owned stock or progression changed, so the yard is worth writing down.
##
## COALESCED, and it has to be: finishing a log deposits one firewood piece at a
## time, so a six-piece log fires this six times in a single frame. Writing the
## file six times for one chop would be six times the I/O for one identical
## result. The deferred flush collapses a whole batch into one write at the end
## of the frame.
##
## Inventory changes, cash, pile state, XP, skill purchases, species purchases,
## mastery, splitter assignment and the selected wood all share this coalescer.
## A transaction may touch several of them in one frame; it still writes once at
## frame end.
func _on_inventory_changed(_item_id: StringName, _new_count: int) -> void:
	_queue_autosave()


func _queue_autosave() -> void:
	if _save_queued:
		return
	_save_queued = true
	_flush_autosave.call_deferred()


func _flush_autosave() -> void:
	_save_queued = false
	if not SaveSystem.save_game():
		push_error("Main: autosave failed — progress since the last good save is at risk.")


## Save on the way out. NOTIFICATION_WM_CLOSE_REQUEST is the only hook that fires
## early enough to still see live state — _exit_tree and PREDELETE run after the
## tree has begun coming apart.
##
## Quitting is UNCONDITIONAL: if the save fails the player is told, but the window
## still closes. A game that refuses to shut down is a worse bug than a lost
## session.
##
## Autosave covers every persisted progression mutation currently in the loop;
## close-request remains a final synchronous safety write.
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
	_splitter_runtime.set_yard_active(false)


func _enter_3d_mode() -> void:
	_action_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_world_root.process_mode = Node.PROCESS_MODE_INHERIT
	_splitter_runtime.set_yard_active(true)


# ---------------------------------------------------------------------------
# The M2 TEMPORARY DEBUG M-key toggle is GONE (2026-08-01). Since 2026-08-03,
# chopping is the production default and YardHUD opens its management panels
# directly over it. The A7 mode signals remain wired for future transitions and
# for the frozen A10 contract; ordinary HUD use no longer emits either one.
#
# The T key that swapped between the chopping block and the tree-felling scene
# went with the tree game in the pivot; the chopping mini-game is the only thing
# under 3D_World_Root and it is instanced in main.tscn.
# ---------------------------------------------------------------------------
