extends Node
## Production-path acceptance for disposable run XP and its visual receipts.
## XP becomes authoritative first; the HUD advances only as pooled orbs reach
## the live fill edge of the bar.

const _WATCHDOG_SECONDS := 10.0

var _passes := 0
var _fails := 0
var _scenario_completed := false
var _watchdog: Timer


func _ready() -> void:
	print("=== RUN XP DELIVERY ACCEPTANCE ===")
	_watchdog = Timer.new()
	_watchdog.one_shot = true
	_watchdog.wait_time = _WATCHDOG_SECONDS
	_watchdog.timeout.connect(_on_watchdog_timeout)
	add_child(_watchdog)
	_watchdog.start()
	await _test_production_xp_delivery()
	_watchdog.stop()
	_check(_scenario_completed,
		"the production XP scenario reached its explicit completion sentinel")
	print("RUN XP DELIVERY: %d passed, %d failed" % [_passes, _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _test_production_xp_delivery() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var main := load("res://scenes/main.tscn").instantiate() as AxemanMain
	add_child(main)
	for _frame: int in range(6):
		await get_tree().process_frame
	main.get_node("StartupOverlay").hide()
	var hud := main.get_node("UI_Overlay/YardHUD") as YardHUD
	hud.show()
	main.call("_enter_world")
	var run := main.get_node("RunDirector") as RunDirector
	var game := main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/Chopping_Minigame")
	var camera := game.get_node("CameraPivot/Camera3D") as Camera3D
	var bar := hud.get_node("XPBar/Progress") as ProgressBar
	var label := hud.get_node("XPBar/LevelLabel") as Label
	run.start_attempt(19019)
	await get_tree().process_frame

	var provider_value: Variant = game.get("_xp_screen_target")
	if not (provider_value is Callable):
		_check(false, "production exposes an XP target provider")
		return
	var provider: Callable = provider_value as Callable
	var initial_target := provider.call() as Vector2 if provider.is_valid() \
		else Vector2(-1.0, -1.0)
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	var bar_rect := bar.get_global_rect()
	var expected_y := (bar_rect.position.y + bar_rect.size.y * 0.5) \
		/ viewport_size.y
	_check(provider.is_valid() and absf(initial_target.y - expected_y) < 0.001 \
		and initial_target.x < 0.02 and initial_target.distance_to(Vector2(0.5, 0.5)) > 0.4,
		"production registers the live XP fill edge instead of the camera-centre fallback")

	var batch_total := [0]
	var batch_count := [0]
	var collected_total := [0]
	var displayed_levels: Array[int] = []
	game.xp_orb_batch_started.connect(func(amount: int) -> void:
		batch_total[0] += amount
		batch_count[0] += 1)
	game.xp_orb_collected.connect(func(amount: int, _tier: int) -> void:
		collected_total[0] += amount)
	hud.displayed_level_gained.connect(func(level: int) -> void:
		displayed_levels.append(level))

	var level_one_span := run.get_xp_to_next_level_for_xp(0)
	var requested := level_one_span + 1
	var first_descriptor := game.get("_current_descriptor") as LogDescriptor
	if first_descriptor == null:
		_check(false, "production stages a run descriptor before XP settlement")
		return
	# This presentation harness deliberately crosses the first threshold in one
	# root. Production snapshots are otherwise immutable; the debug descriptor is
	# adjusted here so the strict root receipt still equals its staged value.
	first_descriptor.xp_reward_snapshot = requested
	var awarded: int = game.call("debug_award_log_xp_event",
		&"manual", first_descriptor.id, true, false, requested)
	var duplicate_award: int = game.call("debug_award_log_xp_event",
		&"manual", first_descriptor.id, true, false, requested)
	var active_orbs := _active_orb_count(game)
	_check(awarded == requested and run.get_xp() == requested \
		and run.get_level() == 2 and batch_count[0] == 1 \
		and batch_total[0] == awarded and active_orbs > 0 \
		and duplicate_award == 0 and GameState.get_xp() == 0,
		"a real production completion awards run XP immediately and launches a nonzero orb batch")
	_check(hud.displayed_xp_total() == 0 and hud.displayed_level() == 1 \
		and is_zero_approx(bar.value) and label.text == "Level 1",
		"the displayed bar and level remain behind the authoritative award while orbs fly")

	var saw_draw := false
	var min_target_distance := INF
	var captured_draw := false
	var saw_level_offer := false
	var deadline := Time.get_ticks_msec() + 4500
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var offer := run.get_current_offer()
		if not offer.is_empty():
			saw_level_offer = true
			var cards: Array = offer.get("cards", [])
			if not cards.is_empty():
				run.choose_run_offer(StringName((cards[0] as Dictionary).get("id", "")))
		var target_pixels := hud.xp_orb_target_normalized() \
			* Vector2(camera.get_viewport().get_visible_rect().size)
		var pool: Array = game.get("_xp_orb_pool")
		for raw_orb: Variant in pool:
			var orb := raw_orb as XPOrb
			if orb == null or not orb.is_processing() or not orb.visible \
					or int(orb.get("_phase")) != XPOrb.Phase.DRAW:
				continue
			saw_draw = true
			var projected := camera.unproject_position(orb.global_position)
			min_target_distance = minf(min_target_distance,
				projected.distance_to(target_pixels))
			if not captured_draw and min_target_distance < 90.0:
				captured_draw = true
				if DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					_capture_if_rendered("/private/tmp/axeman_run_xp_orb_draw.png")
		if _active_orb_count(game) == 0 \
				and hud.displayed_xp_total() == run.get_xp():
			break

	_check(saw_draw and min_target_distance < 90.0,
		"an XP orb enters DRAW and converges on the rendered XP-bar edge")
	_check(collected_total[0] == awarded and _active_orb_count(game) == 0,
		"collected orb shares sum exactly to the authoritative run-XP award")
	_check(hud.displayed_xp_total() == run.get_xp() \
		and hud.displayed_level() == 2 and displayed_levels == [2] \
		and label.text == "Level 2" and saw_level_offer,
		"orb arrival rolls the visible level exactly once and catches displayed XP up")
	_check(absf(float(bar.value) - run.get_level_progress_for_xp(run.get_xp())) \
		< 0.0011,
		"the arrived bar matches disposable run-level progress within its authored step")
	var arrived_target := hud.xp_orb_target_normalized()
	_check(arrived_target.x > initial_target.x,
		"the live orb destination advances with the newly filled portion of the bar")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_capture_if_rendered("/private/tmp/axeman_run_xp_arrived.png")

	var snapshot := run.suspend_attempt()
	_check(int(snapshot.get("xp", -1)) == awarded \
		and int(snapshot.get("level", -1)) == 2,
		"suspension preserves authoritative run XP after its receipts finish")
	run.start_attempt(19020)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(run.get_xp() == 0 and run.get_level() == 1 \
		and hud.displayed_xp_total() == 0 and hud.displayed_level() == 1 \
		and is_zero_approx(bar.value),
		"a fresh attempt resets authoritative and displayed XP together")
	game.set("orbs_enabled", false)
	var second_descriptor := game.get("_current_descriptor") as LogDescriptor
	second_descriptor.xp_reward_snapshot = 1
	var repeated_root_award: int = game.call("debug_award_log_xp_event",
		&"manual", second_descriptor.id, true, false, 1)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(repeated_root_award == 1 and run.get_xp() == 1 \
		and hud.displayed_xp_total() == 1,
		"the same local root id can earn XP in a new run without duplicating within one run")

	var coin_pool := game.get_node("CoinRewardPool") as CoinRewardPool
	var coin_provider: Callable = coin_pool.get("_screen_target") as Callable
	var coin_target := coin_provider.call() as Vector2 if coin_provider.is_valid() \
		else Vector2(0.5, 0.5)
	_check(coin_provider.is_valid() \
		and coin_target.distance_to(hud.coin_target_normalized()) < 0.001 \
		and coin_target.distance_to(Vector2(0.5, 0.5)) > 0.35,
		"production registers the prominent session-cash counter as the coin target")
	coin_pool.begin_burst(game.to_global(Vector3(0.0, 0.62, 0.0)),
		1, 0.0, 0.4, 0.05, 0.0)
	var cash_award := run.award_cash(9)
	coin_pool.queue_payout(cash_award)
	_check(cash_award == 9 and run.get_cash() == 9 \
		and hud.displayed_cash_total() == 0 and hud.pending_coin_count() > 0,
		"session cash is authoritative while its displayed counter waits for the coin")
	var saw_coin_draw := false
	var min_coin_target_distance := INF
	var captured_coin_draw := false
	var coin_deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < coin_deadline:
		await get_tree().process_frame
		var target_pixels := hud.coin_target_normalized() \
			* Vector2(camera.get_viewport().get_visible_rect().size)
		for index: int in range(coin_pool._coins.size()):
			if coin_pool._phases[index] != CoinRewardPool.Phase.DRAW:
				continue
			saw_coin_draw = true
			var projected := camera.unproject_position(
				coin_pool._coins[index].global_position)
			min_coin_target_distance = minf(min_coin_target_distance,
				projected.distance_to(target_pixels))
			if not captured_coin_draw and DisplayServer.get_name() != "headless" \
					and min_coin_target_distance < 90.0:
				captured_coin_draw = true
				await RenderingServer.frame_post_draw
				_capture_if_rendered("/private/tmp/axeman_run_coin_draw.png")
		if hud.pending_coin_count() == 0:
			break
	_check(saw_coin_draw and min_coin_target_distance < 90.0,
		"a cash coin enters DRAW and converges on the rendered session counter")
	_check(hud.pending_coin_count() == 0 and hud.displayed_cash_total() == 9,
		"coin arrival advances displayed session cash exactly to authority")

	game.set("orbs_enabled", true)
	var reserved_orbs: Array[XPOrb] = []
	while true:
		var reserved := game.call("_acquire_xp_orb") as XPOrb
		if reserved == null:
			break
		reserved_orbs.append(reserved)
	var queued_award := run.award_xp(2)
	game.call("_burst_xp_orbs", queued_award,
		Vector3(0.0, float(game.get("_stump_top_y")) + 0.12, 0.0), false)
	_check(not reserved_orbs.is_empty() \
		and (game.get("_queued_xp_bursts") as Array).size() == 1 \
		and hud.displayed_xp_total() < run.get_xp(),
		"a full orb pool queues the complete visual receipt without advancing the bar")
	reserved_orbs[0].cancel_collection()
	game.call("_return_xp_orb_to_pool", reserved_orbs[0])
	reserved_orbs.remove_at(0)
	var queued_deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < queued_deadline:
		await get_tree().process_frame
		if (game.get("_queued_xp_bursts") as Array).is_empty() \
				and _active_orb_count(game) == 0 \
				and hud.displayed_xp_total() == run.get_xp():
			break
	_check((game.get("_queued_xp_bursts") as Array).is_empty() \
		and hud.displayed_xp_total() == run.get_xp(),
		"a returned pool node delivers the queued XP shares exactly once")
	for reserved: XPOrb in reserved_orbs:
		reserved.cancel_collection()
		game.call("_return_xp_orb_to_pool", reserved)

	var to_next_level := run.get_xp_to_next_level_for_xp(run.get_xp())
	var suspend_award := run.award_xp(to_next_level)
	game.call("_burst_xp_orbs", suspend_award,
		Vector3(0.0, float(game.get("_stump_top_y")) + 0.12, 0.0), false)
	_check(_active_orb_count(game) > 0 and run.get_current_offer().is_empty(),
		"a just-earned level still has an in-flight receipt before suspension")
	var midflight_snapshot := run.suspend_attempt()
	var saved_offer: Variant = midflight_snapshot.get("current_offer", {})
	_check(_active_orb_count(game) == 0 and saved_offer is Dictionary \
		and not (saved_offer as Dictionary).is_empty() \
		and int((saved_offer as Dictionary).get("level", 0)) == run.get_level(),
		"suspending mid-flight canonicalizes the earned level into one saved offer")
	var exact_offer := (saved_offer as Dictionary).duplicate(true)
	_check(run.restore_attempt(midflight_snapshot) \
		and run.get_current_offer() == exact_offer and run.is_paused(),
		"restoring a mid-flight suspension preserves the exact cards and pause")
	main.queue_free()
	await get_tree().process_frame
	_scenario_completed = true


func _active_orb_count(game: Node) -> int:
	var count := 0
	var pool: Array = game.get("_xp_orb_pool")
	for raw_orb: Variant in pool:
		var orb := raw_orb as XPOrb
		if orb != null and orb.is_processing():
			count += 1
	return count


func _capture_if_rendered(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	_check(error == OK and image.get_size() == Vector2i(1280, 720),
		"rendered XP checkpoint is 1280x720: %s" % path)


func _on_watchdog_timeout() -> void:
	push_error("FAIL: run XP delivery scenario timed out before its completion sentinel")
	get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + message)
	else:
		_fails += 1
		push_error("FAIL: " + message)
