class_name AxemanMain
extends Node
## Application shell for the survival game. Permanent profile state, disposable
## attempt state, and inventory are saved together but retain separate owners.

const AUTOSAVE_QUIET_SECONDS := 0.5

var _save_queued := false
var _session_started := false
var _autosave_connected := false
var _loading_profile := false
var _autosave_timer: Timer

@onready var _run: RunDirector = $RunDirector
@onready var _action_viewport: SubViewport = $"UI_Canvas/SubViewportContainer/Action_Viewport"
@onready var _world_root: Node3D = $"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root"
@onready var _chopping: Node3D = $"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/Chopping_Minigame"
@onready var _arena: Node3D = $"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/Chopping_Minigame/LooseLogArena"
@onready var _presenter: YardEquipmentPresenter = $"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/Chopping_Minigame/YardEquipment"
@onready var _yard_hud: YardHUD = $UI_Overlay/YardHUD
@onready var _startup_menu: StartupMenu = $StartupOverlay/StartupMenu


func _ready() -> void:
	_autosave_timer = Timer.new()
	_autosave_timer.name = "AutosaveQuietTimer"
	_autosave_timer.one_shot = true
	_autosave_timer.wait_time = AUTOSAVE_QUIET_SECONDS
	_autosave_timer.timeout.connect(_flush_autosave)
	add_child(_autosave_timer)
	_run.bind_runtime(_chopping, _arena)
	_presenter.bind_run_director(_run)
	_yard_hud.bind_run_director(_run)
	_yard_hud.bind_xp_source(_chopping)
	_yard_hud.suspend_requested.connect(_suspend_to_title)
	_yard_hud.abandon_requested.connect(_abandon_to_title)
	_yard_hud.home_requested.connect(_return_home_after_settlement)
	_startup_menu.new_profile_requested.connect(start_new_game)
	_startup_menu.continue_profile_requested.connect(start_fresh_attempt_from_save)
	_startup_menu.resume_attempt_requested.connect(resume_saved_attempt)
	_startup_menu.abandon_attempt_requested.connect(abandon_saved_attempt)
	GameState.profile_changed.connect(_on_profile_changed)
	_run.attempt_finished.connect(_on_attempt_finished)
	_show_startup()
	_warm_initial_vfx.call_deferred()
	get_tree().auto_accept_quit = false


func _warm_initial_vfx() -> void:
	if DisplayServer.get_name() == "headless" \
			or not _chopping.has_method(&"begin_initial_vfx_render_warmup"):
		return
	_chopping.call(&"begin_initial_vfx_render_warmup")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if is_instance_valid(_chopping) \
			and _chopping.has_method(&"end_initial_vfx_render_warmup"):
		_chopping.call(&"end_initial_vfx_render_warmup")


func start_new_game() -> bool:
	if _session_started:
		return false
	_loading_profile = true
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	_run.abandon_attempt()
	if not SaveSystem.clear_attempt_and_save():
		_loading_profile = false
		_startup_menu.show_error("The fresh profile could not be saved. The previous save was preserved when possible.")
		return false
	_loading_profile = false
	_show_startup()
	return true


func start_fresh_attempt_from_save() -> bool:
	if not _load_profile_for_startup():
		return false
	if not SaveSystem.clear_attempt_and_save():
		_startup_menu.show_error("The previous attempt could not be cleared safely.")
		return false
	_begin_session(false)
	return true


func resume_saved_attempt() -> bool:
	if not _load_profile_for_startup():
		return false
	var snapshot := SaveSystem.loaded_attempt_snapshot()
	if snapshot.is_empty() or not _run.restore_attempt(snapshot):
		_startup_menu.show_error("The attempt could not be restored. Your permanent profile is still safe.")
		# Keep the exact snapshot available until the player explicitly abandons it.
		_startup_menu.configure(true, not snapshot.is_empty())
		return false
	_begin_session(true)
	return true


func abandon_saved_attempt() -> bool:
	if not _load_profile_for_startup():
		return false
	_run.abandon_attempt()
	if not SaveSystem.clear_attempt_and_save():
		_startup_menu.show_error("The attempt could not be abandoned safely.")
		return false
	_show_startup()
	return true


func has_started_session() -> bool:
	return _session_started


func autosave_quiet_seconds() -> float:
	return AUTOSAVE_QUIET_SECONDS


func _load_profile_for_startup() -> bool:
	_loading_profile = true
	var result := SaveSystem.load_game()
	_loading_profile = false
	match result:
		SaveSystem.LoadResult.OK:
			return true
		SaveSystem.LoadResult.NO_FILE:
			_startup_menu.configure(false, false)
			_startup_menu.show_error("That save is no longer available. Start a fresh profile.")
		SaveSystem.LoadResult.CORRUPT:
			_startup_menu.show_error("The save could not be read and was not overwritten.")
		SaveSystem.LoadResult.TOO_NEW:
			_startup_menu.show_error("This save belongs to a newer build and was preserved.")
	return false


func _begin_session(restored: bool) -> void:
	if _session_started:
		return
	_session_started = true
	AudioDirector.begin_session()
	_connect_autosave()
	_startup_menu.dismiss()
	_yard_hud.show()
	_enter_world()
	if restored:
		_run.resume_attempt()
	else:
		_run.start_attempt()
	_yard_hud.begin_tutorial(not SaveSystem.has_save())
	_queue_autosave()


func _show_startup() -> void:
	_session_started = false
	_save_queued = false
	if _autosave_timer != null:
		_autosave_timer.stop()
	_yard_hud.hide()
	_world_root.process_mode = Node.PROCESS_MODE_DISABLED
	_action_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_startup_menu.show()
	_startup_menu.process_mode = Node.PROCESS_MODE_INHERIT
	var has_save := SaveSystem.has_save()
	var load_error := ""
	if has_save:
		_loading_profile = true
		var result := SaveSystem.load_game()
		_loading_profile = false
		if result != SaveSystem.LoadResult.OK:
			has_save = false
			load_error = "The saved profile could not be opened and was preserved."
	_startup_menu.configure(has_save,
		SaveSystem.has_suspended_attempt() if has_save else false)
	if not load_error.is_empty():
		_startup_menu.show_error(load_error)


func _enter_world() -> void:
	_world_root.process_mode = Node.PROCESS_MODE_INHERIT
	_action_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _suspend_to_title() -> void:
	if not _session_started:
		return
	var snapshot := _run.suspend_attempt()
	if snapshot.is_empty() or not SaveSystem.save_game(snapshot):
		_yard_hud.show_error(
			"The attempt could not be suspended. It remains paused and safe to retry.")
		return
	AudioDirector.end_session()
	_show_startup()


func _abandon_to_title() -> void:
	if not _session_started:
		return
	_run.pause_attempt()
	if not SaveSystem.clear_attempt_and_save():
		_yard_hud.show_error(
			"The attempt could not be abandoned safely. It remains paused to retry.")
		return
	_run.abandon_attempt()
	AudioDirector.end_session()
	_show_startup()


func _return_home_after_settlement() -> void:
	if not _session_started or _run.phase not in [
			RunDirector.Phase.FAILED, RunDirector.Phase.COMPLETE]:
		return
	if not SaveSystem.clear_attempt_and_save():
		_yard_hud.show_error(
			"The banked run could not be saved. Retry before returning Home.")
		return
	_run.abandon_attempt()
	AudioDirector.end_session()
	_show_startup()


func _connect_autosave() -> void:
	if _autosave_connected:
		return
	_autosave_connected = true
	InventoryManager.inventory_changed.connect(_queue_autosave.unbind(2))
	_run.attempt_snapshot_dirty.connect(_queue_autosave)


func _on_profile_changed() -> void:
	if _loading_profile:
		return
	if _session_started:
		_queue_autosave()
	elif SaveSystem.has_save() and not SaveSystem.save_profile_preserving_attempt():
		_startup_menu.show_error(
			"That Home change is safe in memory but could not be saved yet.")


func _on_attempt_finished(_results: Dictionary) -> void:
	# Banking is exact-once in GameState. Persist it synchronously before the
	# results screen can route Home, closing the quiet-autosave crash window.
	if not SaveSystem.clear_attempt_and_save():
		_yard_hud.show_error(
			"The run was banked in memory, but the profile could not be saved yet.")


func _queue_autosave() -> void:
	if not _session_started:
		return
	_save_queued = true
	_autosave_timer.start()


func _flush_autosave() -> void:
	if not _save_queued or not _session_started:
		return
	_save_queued = false
	var snapshot := _run.to_save_dict() if _run.has_live_attempt() else {}
	if not SaveSystem.save_game(snapshot):
		push_error("Main: autosave failed; current progress is at risk.")


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	if _session_started:
		var snapshot := _run.suspend_attempt() if _run.has_live_attempt() else {}
		if not SaveSystem.save_game(snapshot):
			push_error("Main: save failed while closing.")
	elif SaveSystem.has_save() and not SaveSystem.save_profile_preserving_attempt():
		push_error("Main: Home profile save failed while closing.")
	AudioDirector.end_session()
	get_tree().quit()
