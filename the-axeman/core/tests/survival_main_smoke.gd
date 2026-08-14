extends Node
## Compact production composition gate for Home, run HUD, pause, arrival, and
## settled failure. It uses an isolated save path and never touches player data.

const _SAVE_PATH := "user://survival_main_smoke.cfg"
const _WATCHDOG_SECONDS := 12.0

var _passed := 0
var _failed := 0
var _completed := false


func _ready() -> void:
	get_tree().create_timer(_WATCHDOG_SECONDS).timeout.connect(_on_watchdog)
	SaveSystem.set_save_path_for_tests(_SAVE_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_SAVE_PATH))
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	SaveSystem.clear_attempt_and_save()
	var main := load("res://scenes/main.tscn").instantiate() as AxemanMain
	add_child(main)
	for _frame: int in range(4):
		await get_tree().process_frame
	var world := main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root") as Node3D
	var hud := main.get_node("UI_Overlay/YardHUD") as YardHUD
	var startup := main.get_node("StartupOverlay/StartupMenu") as StartupMenu
	_check(not main.has_started_session() and not hud.visible and startup.visible
		and world.process_mode == Node.PROCESS_MODE_DISABLED,
		"production startup stays dormant until an explicit profile choice")
	_check(startup.find_child("ResumeAttemptButton", true, false) != null
		and startup.find_child("AbandonAttemptButton", true, false) != null,
		"startup presents explicit resume and abandon routes for suspended attempts")

	main.get_node("StartupOverlay").hide()
	hud.show()
	main.call("_enter_world")
	var run := main.get_node("RunDirector") as RunDirector
	var game := main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/Chopping_Minigame")
	var arena := game.get_node("LooseLogArena") as LooseLogArena
	run.start_attempt(303)
	for _frame: int in range(3):
		await get_tree().process_frame
	_check(run.is_gameplay_active() and int(game.call("piece_count")) > 0
		and arena.get_node_or_null("RedBoundary") != null,
		"production start stages a choppable log inside the physical boundary")
	var xp_progress := hud.get_node("XPBar/Progress") as ProgressBar
	var stage_counter := hud.get_node("StageAndRunTimer/StageCountdown") as Label
	_check(xp_progress != null and hud.get_node_or_null("CashCounter/CashIcon") != null
		and stage_counter.text.contains("20:00")
		and hud.get_node_or_null("CashCounter/LockedHomeBank") != null
		and hud.get_node_or_null("StageAndRunTimer/RunTimer") != null
		and hud.get_node("RunPowerSlots").get_child_count() == 6,
		"XP, session cash, locked bank, stage timer, and six run slots are live")

	var presenter := game.get_node("YardEquipment") as YardEquipmentPresenter
	var clear_radius := run.tuning.boundary_radius + run.tuning.yard_prop_clearance
	var arena_is_clear := true
	for landmark: Node in presenter.get_children():
		if landmark is Node3D:
			var at := (landmark as Node3D).position
			arena_is_clear = arena_is_clear \
				and Vector2(at.x, at.z).length() >= clear_radius - 0.001
	_check(arena_is_clear,
		"all physical yard landmarks sit completely beyond the gameplay circle")

	var camera := game.get_node("CameraPivot/Camera3D") as Camera3D
	var start := Vector3(run.tuning.boundary_radius + 0.8, 0.4, -0.2)
	var target := Vector3(0.0, 0.75, 0.0)
	var handoff_is_clear := true
	for sample: int in range(41):
		var point: Vector3 = game.call("_camera_safe_handoff_position",
			float(sample) / 40.0, start, target, camera.global_position,
			run.tuning.block_hop_camera_clearance, run.tuning.block_hop_height)
		var camera_gap := Vector2(point.x - camera.global_position.x,
			point.z - camera.global_position.z).length()
		handoff_is_clear = handoff_is_clear \
			and camera_gap >= run.tuning.block_hop_camera_clearance - 0.001
	_check(handoff_is_clear,
		"claimed logs follow a sampled camera-clear orbit all the way to the block")

	run._process(run.delivery_interval() + 0.01)
	_check(arena.loose_log_count() == 1,
		"production timer instantiates a physical waiting log")
	hud.call("_open_panel", &"pause")
	_check(run.is_paused() and game.process_mode == Node.PROCESS_MODE_DISABLED,
		"production pause panel stops chopping and hazards")
	hud.call("_close_panel")
	_check(run.is_gameplay_active(), "closing production pause resumes the same attempt")

	var bodies := arena.call("_live_bodies") as Array[LooseLogBody]
	if not bodies.is_empty():
		bodies[0].global_position = Vector3(run.tuning.boundary_radius + 0.25, 0.4, 0.0)
		arena.advance_hazards(run.tuning.boundary_grace_seconds, 1.0)
	_check(run.phase == RunDirector.Phase.FAILED
		and hud.get_node("ResultOverlay").visible
		and _visible_button_with_text(hud.get_node("ResultOverlay"), "GO HOME") != null
		and _visible_button_with_text(hud.get_node("ResultOverlay"), "START ANOTHER RUN") == null,
		"production boundary failure banks once and routes the result through Home")

	_completed = true
	_check(_completed, "the production Main smoke reached its completion sentinel")
	print("SURVIVAL MAIN SMOKE: %d passed, %d failed" % [_passed, _failed])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_SAVE_PATH))
	SaveSystem.reset_save_path_after_tests()
	get_tree().quit(0 if _failed == 0 else 1)


func _visible_button_with_text(root: Node, text: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.visible and button.text == text:
			return button
	return null


func _on_watchdog() -> void:
	if _completed:
		return
	push_error("FAIL: production Main smoke timed out")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_SAVE_PATH))
	SaveSystem.reset_save_path_after_tests()
	get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("PASS: " + message)
	else:
		_failed += 1
		push_error("FAIL: " + message)
