extends Node
## Production acceptance for the scheduled five-log, top-down stump encounter.

const _WATCHDOG_SECONDS := 30.0
const _SAVE_PATH := "user://boss_stack_acceptance.cfg"
const _CUT_SOURCE := &"boss_stack_acceptance"

var _passes := 0
var _fails := 0
var _completed := false


func _ready() -> void:
	print("=== BOSS STACK ACCEPTANCE ===")
	get_tree().create_timer(_WATCHDOG_SECONDS).timeout.connect(_on_watchdog)
	await _run_scenario()
	_completed = true
	_check(_completed, "the production boss-stack scenario reached its completion sentinel")
	print("BOSS STACK: %d passed, %d failed" % [_passes, _fails])
	_cleanup()
	get_tree().quit(0 if _fails == 0 else 1)


func _run_scenario() -> void:
	_check(SaveSystem.set_save_path_for_tests(_SAVE_PATH),
		"the boss-stack suite uses an isolated SaveSystem path")
	_remove_save_files()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	_check(SaveSystem.clear_attempt_and_save(),
		"the isolated Home profile is durable before production Main boots")

	var main := load("res://scenes/main.tscn").instantiate() as AxemanMain
	add_child(main)
	await _wait_frames(6)
	_check(main.start_fresh_attempt_from_save(),
		"production Main starts the encounter test attempt")
	await _wait_frames(3)
	var run := main.get_node("RunDirector") as RunDirector
	var game := main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/Chopping_Minigame")
	var hud := main.get_node("UI_Overlay/YardHUD") as YardHUD
	game.set("orbs_enabled", false)
	var yard := SurvivorsContent.yards().by_id(GameState.get_selected_yard())
	var boss := yard.bosses[0] if yard != null and not yard.bosses.is_empty() else null
	_check(boss != null and run.tuning.boss_stack_log_count == 5,
		"yard one retains an authored schedule and the encounter count is exactly five")
	if boss == null:
		main.queue_free()
		return

	# Cross the real first schedule while the initial ordinary root still owns the
	# block. The encounter must wait rather than deleting current player work.
	run.set("_elapsed_seconds", boss.scheduled_seconds - 0.05)
	run.call("_process", 0.10)
	var queued := run.to_save_dict()
	_check((queued.get("pending_boss_schedule_indices", []) as Array).size() == 1 \
		and String(queued.get("active_boss_id", "")).is_empty(),
		"a due boss waits behind the current active root")
	_complete_current_root(game)
	await _wait_frames(2)
	await get_tree().create_timer(0.5).timeout
	var stack_state: Dictionary = game.call("debug_boss_stack_state")
	var stack_save := run.to_save_dict()
	var boss_label := hud.get_node("BossStackStatus") as Label
	var tracking_fov := float(stack_state.get("camera_fov", 0.0))
	var previous_camera_target_y := float(stack_state.get(
		"camera_target_pivot_y", 0.0))
	var all_layers_tracked := true
	_check(bool(stack_state.get("active", false)) \
		and int(stack_state.get("pending_visual_count", -1)) == 4 \
		and int(stack_state.get("cuttable_count", -1)) == 1 \
		and (stack_save.get("boss_stack_remaining", []) as Array).size() == 4,
		"all five roots occupy the stump while only the top root is cuttable")
	_check(boss_label.visible and boss_label.text.contains("5 LOGS") \
		and is_equal_approx(float(stack_state.get("camera_fov", 0.0)),
			float(stack_state.get("camera_base_fov", -1.0))) \
		and (stack_state.get("camera_position", Vector3.ZERO) as Vector3) \
			.is_finite() \
		and (stack_state.get("camera_base_local_position", Vector3.ZERO) \
			as Vector3).is_equal_approx(stack_state.get(
				"camera_local_position", Vector3.ONE) as Vector3) \
		and previous_camera_target_y \
			> float(stack_state.get("camera_base_pivot_y", 0.0)) \
		and is_equal_approx(float(stack_state.get("camera_pivot_y", 0.0)),
			previous_camera_target_y) \
		and is_equal_approx(run.tuning.boss_stack_camera_lift_fraction, 1.0) \
		and bool(stack_state.get("active_log_visible", false)),
		"the HUD starts at five while the ordinary-distance/FOV camera keeps the complete exposed top root in frame")
	_check(_stack_rewards_total(stack_save) == Vector2i(
		boss.cash_jackpot, int(round(float(boss.xp_jackpot) \
			* run.tuning.global_xp_gain_multiplier))) \
		and _stack_uses_ordinary_hardness(stack_save,
			yard.hardness_multiplier(run.get_level())),
		"the five roots split the cash and globally boosted XP jackpots exactly while using ordinary current-level hardness")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_capture("/private/tmp/axeman_boss_stack.png")

	# A suspended encounter restores its active top root, four lower visuals,
	# counter, and top-root camera target without rerolling identities or rewards.
	var snapshot := run.to_save_dict()
	var signature := _boss_signature(snapshot)
	_check(run.restore_attempt(snapshot),
		"an active five-log encounter restores from its production attempt snapshot")
	await _wait_frames(3)
	var restored_state: Dictionary = game.call("debug_boss_stack_state")
	_check(_boss_signature(run.to_save_dict()) == signature \
		and int(restored_state.get("pending_visual_count", -1)) == 4 \
		and int(restored_state.get("cuttable_count", -1)) == 1,
		"restore preserves the exact active top and remaining four-log stack")
	run.resume_attempt()

	var expected_counts := [4, 3, 2, 1]
	for expected: int in expected_counts:
		_complete_current_root(game)
		await _wait_frames(2)
		_resolve_offer(run)
		await _wait_frames(2)
		var state: Dictionary = game.call("debug_boss_stack_state")
		_check(bool(state.get("active", false)) \
			and int(state.get("pending_visual_count", -1)) == expected - 1 \
			and int(state.get("cuttable_count", -1)) == 1 \
			and boss_label.text.contains("%d LOG" % expected),
			"clearing the top root exposes exactly the next layer (%d remain)" % expected)
		await get_tree().create_timer(0.5).timeout
		var tracked_state: Dictionary = game.call("debug_boss_stack_state")
		var next_target_y := float(tracked_state.get(
			"camera_target_pivot_y", 0.0))
		all_layers_tracked = all_layers_tracked \
			and is_equal_approx(float(tracked_state.get("camera_fov", 0.0)),
				tracking_fov) \
			and is_equal_approx(float(tracked_state.get("camera_pivot_y", 0.0)),
				next_target_y) \
			and next_target_y < previous_camera_target_y \
			and bool(tracked_state.get("active_log_visible", false))
		previous_camera_target_y = next_target_y
		if expected == 1 and DisplayServer.get_name() != "headless":
			# The latest rendered frame already reflects the settled 0.5-second
			# tracking transition. Do not wait on a post-draw signal while a level
			# offer may have paused the production viewport.
			_capture("/private/tmp/axeman_boss_stack_one.png")
	_check(all_layers_tracked,
		"the fixed-FOV camera follows each newly exposed top root downward and keeps it fully visible")

	_complete_current_root(game)
	await _wait_frames(2)
	_resolve_offer(run)
	await get_tree().create_timer(0.5).timeout
	var cleared_state: Dictionary = game.call("debug_boss_stack_state")
	var cleared_save := run.to_save_dict()
	_check(not bool(cleared_state.get("active", true)) \
		and int(cleared_state.get("pending_visual_count", -1)) == 0 \
		and not boss_label.visible \
		and is_equal_approx(float(cleared_state.get("camera_pivot_y", -1.0)),
			float(cleared_state.get("camera_base_pivot_y", 0.0))),
		"the fifth clear reaches zero, hides the counter, and restores the ordinary camera " \
			+ "[state=%s label_visible=%s]" % [cleared_state, boss_label.visible])
	_check(int(cleared_save.get("bosses_defeated", 0)) == 1 \
		and (cleared_save.get("pending_blueprint_rolls", []) as Array).size() == 1,
		"only clearing the whole stack records one boss and one pending Blueprint")

	main.queue_free()
	await get_tree().process_frame


func _complete_current_root(game: Node) -> void:
	game.call("apply_run_power_cuts", _CUT_SOURCE, 6, &"largest", false)
	game.call("_settle_finished_firewood")


func _resolve_offer(run: RunDirector) -> void:
	var offer := run.get_current_offer()
	if offer.is_empty():
		return
	var cards: Variant = offer.get("cards", [])
	if cards is Array and not (cards as Array).is_empty():
		run.choose_run_offer(StringName((cards as Array)[0].get("id", "")))


func _stack_rewards_total(snapshot: Dictionary) -> Vector2i:
	var cash := 0
	var xp := 0
	var chopping: Variant = snapshot.get("chopping", {})
	if chopping is Dictionary:
		var active: Variant = (chopping as Dictionary).get("descriptor", {})
		if active is Dictionary:
			cash += int((active as Dictionary).get("cash_reward_snapshot", 0))
			xp += int((active as Dictionary).get("xp_reward_snapshot", 0))
	for raw: Variant in snapshot.get("boss_stack_remaining", []):
		if raw is Dictionary:
			cash += int((raw as Dictionary).get("cash_reward_snapshot", 0))
			xp += int((raw as Dictionary).get("xp_reward_snapshot", 0))
	return Vector2i(cash, xp)


func _stack_uses_ordinary_hardness(snapshot: Dictionary,
		expected: float) -> bool:
	var descriptors: Array = (snapshot.get("boss_stack_remaining", []) as Array).duplicate()
	var chopping: Variant = snapshot.get("chopping", {})
	if chopping is Dictionary:
		descriptors.append((chopping as Dictionary).get("descriptor", {}))
	if descriptors.size() != 5:
		return false
	for raw: Variant in descriptors:
		if not (raw is Dictionary) or not is_equal_approx(
				float((raw as Dictionary).get("hardness_snapshot", 0.0)), expected):
			return false
	return true


func _boss_signature(snapshot: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	var chopping: Variant = snapshot.get("chopping", {})
	if chopping is Dictionary:
		ids.append(String((chopping as Dictionary).get("descriptor", {}).get("id", "")))
	for raw: Variant in snapshot.get("boss_stack_remaining", []):
		if raw is Dictionary:
			ids.append(String((raw as Dictionary).get("id", "")))
	return ids


func _capture(path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	_check(image.save_png(path) == OK,
		"the rendered boss-stack screenshot writes successfully (%s)" \
			% path.get_file())


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
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})


func _on_watchdog() -> void:
	if _completed:
		return
	push_error("FAIL: production boss-stack scenario timed out")
	_cleanup()
	get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + message)
	else:
		_fails += 1
		push_error("FAIL: " + message)
