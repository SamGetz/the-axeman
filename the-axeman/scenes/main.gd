extends Node
## FILE: res://scenes/main.gd
## ATTACHES TO: Main (Node), the root of res://scenes/main.tscn.
##
## Main scene shell. Owns the startup transaction, autosave boundary, and A10
## 2D/3D mode switch:
##   2D mode: Action_Viewport stops rendering, 3D_World_Root stops processing.
##   3D mode (on EventBus.minigame_entered): both restored.
## No gameplay logic lives here. Gameplay UI goes in UI_Overlay (A9), never
## UI_Canvas.
##
## The chopping game is now the default and only production view. A10's mode
## switch remains available for future transitions, but management opens as HUD
## panels over the live chopping scene instead of entering a separate 2D mode.

var _save_queued := false
var _session_started := false
var _autosave_connected := false
var _autosave_timer: Timer

## Performance boundary, not economy tuning: progression bursts restart this
## one-shot timer so disk serialization runs once after the burst goes quiet.
const AUTOSAVE_QUIET_SECONDS := 0.5

@onready var _action_viewport: SubViewport = $"UI_Canvas/SubViewportContainer/Action_Viewport"
@onready var _world_root: Node3D = $"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root"
@onready var _chopping_minigame: Node3D = $"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/Chopping_Minigame"
@onready var _splitter_runtime: MechanicalSplitterRuntime = $"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/Chopping_Minigame/MechanicalSplitterRuntime"
@onready var _yard_hud: Control = $UI_Overlay/YardHUD
@onready var _startup_menu: StartupMenu = $StartupOverlay/StartupMenu


func _ready() -> void:
	_autosave_timer = Timer.new()
	_autosave_timer.name = "AutosaveQuietTimer"
	_autosave_timer.one_shot = true
	_autosave_timer.wait_time = AUTOSAVE_QUIET_SECONDS
	_autosave_timer.timeout.connect(_flush_autosave)
	add_child(_autosave_timer)
	EventBus.minigame_entered.connect(_on_minigame_entered)
	EventBus.minigame_exited.connect(_on_minigame_exited)
	_yard_hud.bind_splitter_runtime(_splitter_runtime)
	_yard_hud.bind_xp_source(_chopping_minigame)
	_yard_hud.hide()
	_enter_2d_mode()
	_startup_menu.new_game_requested.connect(start_new_game)
	_startup_menu.load_game_requested.connect(load_saved_game)
	_startup_menu.configure(SaveSystem.has_save())
	_initial_vfx_render_warmup.call_deferred()

	# Godot tears the window down the moment it is closed unless told otherwise.
	# While the startup menu is open we must also intercept close so stale autoload
	# memory can never overwrite the save the player has not chosen to load.
	get_tree().auto_accept_quit = false


## RID creation does not compile Compatibility-renderer pipelines. Give every
## pooled reward surface one covered draw submission behind the opaque startup
## menu, then return the dormant yard to its normal disabled menu state.
func _initial_vfx_render_warmup() -> void:
	if not is_inside_tree():
		return
	# Let the boot boundary settle in its authored disabled state first. A human
	# cannot act inside this single frame, and startup harnesses can still observe
	# the exact menu contract before the covered renderer-only pass begins.
	await get_tree().process_frame
	if not is_inside_tree() or _session_started:
		return
	# Rendering once does not require advancing gameplay. UPDATE_ONCE returns to
	# disabled automatically, preserving the startup boundary while still forcing
	# real first-draw pipeline compilation.
	_world_root.process_mode = Node.PROCESS_MODE_DISABLED
	_chopping_minigame.call("begin_initial_vfx_render_warmup")
	_action_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	_chopping_minigame.call("end_initial_vfx_render_warmup")
	if not _session_started:
		_enter_2d_mode()


## Starts a genuinely fresh yard. SaveSystem's temp-file replacement makes this
## atomic: an existing save is replaced only after the fresh state is fully
## written. If writing fails, the old save is loaded back into memory and the
## player remains at the menu.
func start_new_game() -> bool:
	if _session_started:
		return false
	var had_save := SaveSystem.has_save()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	if not SaveSystem.save_game():
		if had_save:
			SaveSystem.load_game()
		_startup_menu.show_error(
			"The new yard could not be saved. Your existing save was left intact.")
		return false
	_finish_startup(true)
	print("Main: new game started.")
	return true


## Loads only when the player asks. Failures stay on the menu rather than
## silently resetting the yard and allowing the first autosave to clobber it.
func load_saved_game() -> bool:
	if _session_started:
		return false
	var result := SaveSystem.load_game()
	match result:
		SaveSystem.LoadResult.OK:
			_finish_startup(false)
			print("Main: save loaded — %d cash, %d wood chopped lifetime." % [
				GameState.get_cash(), GameState.get_lifetime_wood_chopped(),
			])
			return true
		SaveSystem.LoadResult.NO_FILE:
			_startup_menu.configure(false)
			_startup_menu.show_error("That save is no longer available. Start a new yard.")
		SaveSystem.LoadResult.CORRUPT:
			_startup_menu.show_error(
				"The saved yard could not be read. It was not overwritten.")
		SaveSystem.LoadResult.TOO_NEW:
			_startup_menu.configure(SaveSystem.has_save())
			_startup_menu.show_error(
				"This save belongs to a newer build and was preserved as a backup.")
	return false


func has_started_session() -> bool:
	return _session_started


func _finish_startup(is_fresh_game: bool) -> void:
	if _session_started:
		return
	_session_started = true
	AudioDirector.begin_session()
	_connect_autosave()
	_resolve_offline_progress()
	_startup_menu.dismiss()
	_yard_hud.show()
	_enter_3d_mode()
	_yard_hud.call_deferred("begin_tutorial", is_fresh_game)


func _resolve_offline_progress() -> void:
	var now := int(Time.get_unix_time_from_system())
	if CompanyLogistics.can_run_offline():
		var receipt := CompanySimulation.simulate(
			GameState.get_company_simulation_input(), now, true)
		if receipt.processed_logs() > 0:
			CompanyLogistics.apply_receipt(receipt)
			return
	GameState.set_company_clock_anchor(now)


## Autosave whenever owned stock OR progression moves. Connected only AFTER a
## deliberate successful New Game or Load Game: every serialiser emits as it
## restores fields, and menu-time mutations must never overwrite an unchosen
## save.
func _connect_autosave() -> void:
	if _autosave_connected:
		return
	_autosave_connected = true
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
	GameState.commission_state_changed.connect(_queue_autosave)
	GameState.reputation_changed.connect(_queue_autosave.unbind(1))
	GameState.craftsmanship_changed.connect(_queue_autosave.unbind(2))
	GameState.company_logistics_changed.connect(_queue_autosave)
	GameState.regional_network_changed.connect(_queue_autosave)
	GameState.company_strategy_changed.connect(_queue_autosave)
	GameState.earth_campaign_changed.connect(_queue_autosave)
	GameState.launch_program_changed.connect(_queue_autosave)
	GameState.expedition_changed.connect(_queue_autosave)
	GameState.alien_campaign_changed.connect(_queue_autosave)
	GameState.feature_introduced.connect(_queue_autosave.unbind(1))


## ---------------------------------------------------------------- autosave
## Owned stock or progression changed, so the yard is worth writing down.
##
## COALESCED, and it has to be: finishing a log deposits pieces, cash and XP over
## several visual frames. Writing once per signal stalls those same reward
## frames with repeated ConfigFile serialization. A short restartable quiet
## window collapses the complete burst into one write; the close hook below
## remains a synchronous safety save.
##
## Inventory changes, cash, pile state, XP, skill purchases, species purchases,
## mastery, splitter assignment and the selected wood all share this coalescer.
## A transaction may touch several of them across a reward animation; it still
## writes once after the last mutation.
func _on_inventory_changed(_item_id: StringName, _new_count: int) -> void:
	_queue_autosave()


func _queue_autosave() -> void:
	if not _session_started:
		return
	_save_queued = true
	_autosave_timer.start()


func _flush_autosave() -> void:
	if not _save_queued:
		return
	_save_queued = false
	if not SaveSystem.save_game():
		push_error("Main: autosave failed — progress since the last good save is at risk.")


func autosave_quiet_seconds() -> float:
	return AUTOSAVE_QUIET_SECONDS


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
	if _session_started and not SaveSystem.save_game():
		push_error("Main: the save failed on quit — this session's progress is lost.")
	AudioDirector.end_session()
	get_tree().quit()


func _on_minigame_entered(_biome: Enums.Biome) -> void:
	if not _session_started:
		return
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
