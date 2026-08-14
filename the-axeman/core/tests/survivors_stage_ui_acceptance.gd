extends Node
## Production acceptance for the 20-minute stage decision and results HUD.
##
## This test deliberately boots the real Main scene twice around a persisted
## stage-clear snapshot. It advances RunDirector through its clock seam rather
## than waiting for a real-time twenty-minute attempt.

const _WATCHDOG_SECONDS := 20.0
const _SAVE_PATH := "user://survivors_stage_ui_acceptance.cfg"
const _STARTING_HOME_CASH := 500
const _SESSION_CASH := 137
const _FAILURE_CASH := 23

var _passes := 0
var _fails := 0
var _completed := false
var _finished_results: Array[Dictionary] = []


func _ready() -> void:
	print("=== SURVIVORS STAGE UI ACCEPTANCE ===")
	get_tree().create_timer(_WATCHDOG_SECONDS).timeout.connect(_on_watchdog)
	await _run_scenario()
	_completed = true
	_check(_completed, "the production stage/results scenario reached its completion sentinel")
	print("SURVIVORS STAGE UI: %d passed, %d failed" % [_passes, _fails])
	_cleanup()
	get_tree().quit(0 if _fails == 0 else 1)


func _run_scenario() -> void:
	_check(SaveSystem.set_save_path_for_tests(_SAVE_PATH),
		"the stage UI suite uses an isolated SaveSystem path")
	_remove_save_files()
	GameState.reset_to_defaults()
	GameState.apply_save_dict({"home_cash": _STARTING_HOME_CASH})
	InventoryManager.apply_save_dict({})
	_check(SaveSystem.clear_attempt_and_save(),
		"the isolated Home profile is durable before production Main boots")

	var first_main := load("res://scenes/main.tscn").instantiate() as AxemanMain
	add_child(first_main)
	await _wait_frames(6)
	_check(first_main.start_fresh_attempt_from_save(),
		"production Main starts a fresh attempt from the isolated Home profile")
	await _wait_frames(3)
	var first_run := first_main.get_node("RunDirector") as RunDirector
	var first_hud := first_main.get_node("UI_Overlay/YardHUD") as YardHUD
	var stage_label := first_hud.get_node(
		"StageAndRunTimer/StageCountdown") as Label
	var cash_label := first_hud.get_node("CashCounter/CashLabel") as Label
	var bank_label := first_hud.get_node("CashCounter/LockedHomeBank") as Label
	_check(stage_label.is_visible_in_tree() and stage_label.text.contains("20:00") \
		and first_run.stage_remaining_ms() > 1_199_000 \
		and first_run.stage_remaining_ms() <= 1_200_000,
		"StageCountdown begins at the authored 20:00 duration")

	var coin_target := first_hud.coin_target_normalized()
	var cash_target := _normalized_center(cash_label)
	var bank_target := _normalized_center(bank_label)
	_check(cash_label != bank_label and cash_label.is_visible_in_tree() \
		and bank_label.is_visible_in_tree() \
		and bank_label.text.contains(str(_STARTING_HOME_CASH)) \
		and bank_label.text.contains("LOCKED") \
		and coin_target.distance_to(cash_target) < 0.001 \
		and coin_target.distance_to(bank_target) > 0.01,
		"the locked Home bank is visible and separate from CashLabel's coin target")
	_check(first_run.award_cash(_SESSION_CASH) == _SESSION_CASH,
		"the attempt has a non-zero session purse for settlement coverage")
	await get_tree().process_frame
	_check(cash_label.text == str(_SESSION_CASH) \
		and bank_label.text.contains(str(_STARTING_HOME_CASH)) \
		and GameState.get_home_cash() == _STARTING_HOME_CASH,
		"session cash updates its own counter without changing the locked Home bank")

	first_run.call("_process", 1.25)
	var before_menu_ms := first_run.elapsed_ms()
	var before_menu_countdown := stage_label.text
	var quick_menu := first_hud.get_node("QuickMenu") as HBoxContainer
	var pause_button := _find_button_with_text(quick_menu, "PAUSE")
	_check(pause_button != null, "the production Pause control is available")
	if pause_button != null:
		pause_button.pressed.emit()
	await get_tree().process_frame
	var pause_overlay := first_hud.get_node("ModalBackdrop") as Control
	var close_button := _find_button_with_text(pause_overlay, "CLOSE")
	first_run.call("_process", 9.0)
	_check(first_run.is_paused() and pause_overlay.visible \
		and first_run.elapsed_ms() == before_menu_ms \
		and stage_label.text == before_menu_countdown,
		"opening a menu pauses the stage clock and countdown")
	_check(close_button != null, "the paused menu exposes its Close control")
	if close_button != null:
		close_button.pressed.emit()
	await get_tree().process_frame
	_check(not first_run.is_paused(), "closing the pause menu resumes live play")

	# Inject the production clock to one tick before the authored limit, then let
	# RunDirector perform its normal threshold transition.
	first_run.set("_elapsed_seconds", first_run.stage_duration_seconds() - 0.05)
	first_run.call("_process", 0.10)
	await get_tree().process_frame
	var first_results := first_hud.get_node("ResultOverlay") as Control
	var first_continue := _find_button_with_text(first_results, "CONTINUE ENDLESS")
	var first_bank := _find_button_with_text(first_results, "BANK & GO HOME")
	var decision_signature := _stage_decision_signature(first_results)
	_check(first_run.phase == RunDirector.Phase.EARTH_CLEAR \
		and first_run.is_paused() and first_run.stage_remaining_ms() == 0 \
		and stage_label.text.contains("00:00") and first_results.visible,
		"the stage reaches zero, enters EARTH_CLEAR, and pauses behind results")
	_check(first_continue != null and first_continue.visible \
		and first_bank != null and first_bank.visible,
		"stage clear offers CONTINUE ENDLESS and BANK & GO HOME")

	var decision_snapshot := first_run.suspend_attempt()
	_check(not decision_snapshot.is_empty() \
		and int(decision_snapshot.get("phase", -1)) == RunDirector.Phase.EARTH_CLEAR \
		and SaveSystem.save_game(decision_snapshot),
		"suspending at the decision persists the EARTH_CLEAR snapshot")
	first_main.queue_free()
	await _wait_frames(3)
	AudioDirector.end_session()

	# Clear memory to make this a genuine disk-backed restore rather than an
	# in-process RunDirector round trip.
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var restored_main := load("res://scenes/main.tscn").instantiate() as AxemanMain
	add_child(restored_main)
	await _wait_frames(6)
	_check(restored_main.resume_saved_attempt(),
		"a second production Main resumes the saved stage decision")
	await _wait_frames(4)
	var run := restored_main.get_node("RunDirector") as RunDirector
	var hud := restored_main.get_node("UI_Overlay/YardHUD") as YardHUD
	var results_overlay := hud.get_node("ResultOverlay") as Control
	var restored_signature := _stage_decision_signature(results_overlay)
	_check(run.phase == RunDirector.Phase.EARTH_CLEAR and run.is_paused() \
		and run.get_cash() == _SESSION_CASH and results_overlay.visible \
		and restored_signature == decision_signature,
		"restore remains at EARTH_CLEAR with the identical two-action decision")

	var restored_continue := _find_button_with_text(
		results_overlay, "CONTINUE ENDLESS")
	if restored_continue != null:
		restored_continue.pressed.emit()
	await get_tree().process_frame
	_check(run.phase == RunDirector.Phase.OVERFLOW and not run.is_paused() \
		and not results_overlay.visible \
		and GameState.get_home_cash() == _STARTING_HOME_CASH,
		"Continue enters OVERFLOW without banking the session purse")

	# Re-enter the saved decision to exercise the other mutually-exclusive
	# branch without creating a second artificial twenty-minute run.
	_check(run.restore_attempt(decision_snapshot),
		"the saved decision can be restored to exercise its cash-out branch")
	await _wait_frames(2)
	run.attempt_finished.connect(_on_attempt_finished)
	var restored_bank := _find_button_with_text(results_overlay, "BANK & GO HOME")
	if restored_bank != null:
		restored_bank.pressed.emit()
	await _wait_frames(2)
	var bank_after_cash_out := GameState.get_home_cash()
	var cash_out_results: Dictionary = _finished_results.back() \
		if not _finished_results.is_empty() else {}
	_check(run.phase == RunDirector.Phase.COMPLETE and run.is_paused() \
		and bank_after_cash_out == _STARTING_HOME_CASH + _SESSION_CASH \
		and _finished_results.size() == 1 \
		and int(cash_out_results.get("phase", -1)) == RunDirector.Phase.COMPLETE \
		and String(cash_out_results.get("result_kind", "")) == "cash_out",
		"cash-out banks the full purse once and emits COMPLETE results")
	_check(results_overlay.visible \
		and _visible_button_texts(results_overlay) == ["GO HOME"],
		"the completed cash-out result exposes only GO HOME")
	_check(not run.cash_out_stage() \
		and GameState.get_home_cash() == bank_after_cash_out \
		and _finished_results.size() == 1,
		"repeating cash-out cannot bank or emit results a second time")

	# A separate production run proves the failure result has no endless or
	# cash-out affordance. The failure itself still banks through the same exact-
	# once authority.
	run.start_attempt(88103)
	_check(run.award_cash(_FAILURE_CASH) == _FAILURE_CASH,
		"a follow-up run has a purse for failure settlement coverage")
	run.call("_on_breach_expired", &"acceptance_boundary_root")
	await _wait_frames(2)
	var failure_results: Dictionary = _finished_results.back() \
		if not _finished_results.is_empty() else {}
	_check(run.phase == RunDirector.Phase.FAILED and run.is_paused() \
		and String(failure_results.get("result_kind", "")) == "failure" \
		and _finished_results.size() == 2,
		"a boundary failure emits one paused failure result")
	_check(results_overlay.visible \
		and _visible_button_texts(results_overlay) == ["GO HOME"] \
		and _find_button_with_text(results_overlay, "CONTINUE ENDLESS") == null \
		and _find_button_with_text(results_overlay, "BANK & GO HOME") == null,
		"failure offers only GO HOME")

	restored_main.queue_free()
	await get_tree().process_frame
	AudioDirector.end_session()


func _on_attempt_finished(results: Dictionary) -> void:
	_finished_results.append(results.duplicate(true))


func _stage_decision_signature(root: Node) -> Array[String]:
	var signature: Array[String] = []
	# The title node is dynamically built without a public name, so visible
	# button copy is the stable public decision signature.
	for text: String in _visible_button_texts(root):
		signature.append(text)
	return signature


func _visible_button_texts(root: Node) -> Array[String]:
	var texts: Array[String] = []
	for node: Node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.visible and not button.is_queued_for_deletion():
			texts.append(button.text)
	return texts


func _find_button_with_text(root: Node, text: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == text and button.visible \
				and not button.is_queued_for_deletion():
			return button
	return null


func _normalized_center(control: Control) -> Vector2:
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2.ZERO
	var centre := control.get_global_rect().get_center()
	return Vector2(centre.x / viewport_size.x, centre.y / viewport_size.y)


func _wait_frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


func _remove_save_files() -> void:
	var absolute := ProjectSettings.globalize_path(_SAVE_PATH)
	for suffix: String in ["", ".tmp", ".replacing"]:
		DirAccess.remove_absolute(absolute + suffix)


func _cleanup() -> void:
	_remove_save_files()
	SaveSystem.reset_save_path_after_tests()
	AudioDirector.end_session()


func _on_watchdog() -> void:
	if _completed:
		return
	push_error("FAIL: survivors stage UI scenario timed out")
	_cleanup()
	get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + message)
	else:
		_fails += 1
		push_error("FAIL: " + message)
