extends Node
## Production UI acceptance for the level-arrival -> saved run-offer contract.

const _WATCHDOG_SECONDS := 12.0
const _SAVE_PATH := "user://run_power_offer_acceptance.cfg"

var _passes := 0
var _fails := 0
var _completed := false


func _ready() -> void:
	print("=== RUN POWER OFFER ACCEPTANCE ===")
	var watchdog := get_tree().create_timer(_WATCHDOG_SECONDS)
	watchdog.timeout.connect(_on_watchdog)
	await _run_scenario()
	_completed = true
	_check(_completed, "the production offer scenario reached its completion sentinel")
	print("RUN POWER OFFER: %d passed, %d failed" % [_passes, _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _run_scenario() -> void:
	SaveSystem.set_save_path_for_tests(_SAVE_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_SAVE_PATH))
	GameState.reset_to_defaults()
	GameState.apply_save_dict({"home_cash": 1000000})
	InventoryManager.apply_save_dict({})
	var luck_purchased := true
	for _rank: int in range(5):
		luck_purchased = GameState.purchase_meta_upgrade(&"luck") \
			and luck_purchased
	_check(luck_purchased and GameState.get_meta_upgrade_rank(&"luck") == 5,
		"the Home profile can own max-rank Luck before a production run")
	_check(SaveSystem.clear_attempt_and_save(),
		"the production Home profile is isolated and durable before boot")

	var main := load("res://scenes/main.tscn").instantiate() as AxemanMain
	add_child(main)
	for _frame: int in range(6):
		await get_tree().process_frame
	main.get_node("StartupOverlay").hide()
	main.call("_enter_world")
	var hud := main.get_node("UI_Overlay/YardHUD") as YardHUD
	hud.show()
	var run := main.get_node("RunDirector") as RunDirector
	var game := main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/Chopping_Minigame")
	game.set("orbs_enabled", false)
	var luck_seed := await _find_four_card_luck_seed(run, hud)
	_check(luck_seed > 0,
		"max-rank Luck opens four distinct cards in the production offer UI")
	run.abandon_attempt()
	await get_tree().process_frame
	var luck_refund := GameState.refund_all_meta_upgrades()
	_check(luck_refund > 0 and GameState.get_meta_upgrade_rank(&"luck") == 0,
		"the focused Luck setup is removed before the utility-card scenario")
	_check(GameState.purchase_meta_upgrade(&"rerolls") \
		and GameState.purchase_meta_upgrade(&"banishes") \
		and GameState.purchase_meta_upgrade(&"banishes") \
		and GameState.purchase_meta_upgrade(&"banishes"),
		"home utility ranks can seed one reroll and three banishes before a run")
	run.start_attempt(44101)
	await get_tree().process_frame
	var quick_menu := hud.get_node("QuickMenu") as HBoxContainer
	var pause_button := quick_menu.get_child(0) as Button
	pause_button.pressed.emit()
	await get_tree().process_frame
	var pause_backdrop := hud.get_node("ModalBackdrop") as Control
	var close_button := _find_button_with_text(pause_backdrop, "CLOSE")
	var suspend_button := _find_button_with_text(pause_backdrop,
		"SUSPEND THIS ATTEMPT")
	var abandon_button := _find_button_with_text(pause_backdrop,
		"ABANDON ATTEMPT")
	_check(run.is_paused() and pause_backdrop.visible and close_button != null \
		and suspend_button != null and not suspend_button.pressed.get_connections().is_empty() \
		and abandon_button != null and not abandon_button.pressed.get_connections().is_empty(),
		"Pause, Close, Suspend, and Abandon controls are visible and connected")
	close_button.pressed.emit()
	await get_tree().process_frame
	_check(not run.is_paused() and not pause_backdrop.visible,
		"the production Close button resumes the paused run")
	var xp_bar := hud.get_node("XPBar") as Control
	var cash_counter := hud.get_node("CashCounter") as Control
	var power_slots_control := hud.get_node("RunPowerSlots") as Control
	_check(xp_bar.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and cash_counter.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and power_slots_control.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and quick_menu.size.x <= 100.0,
		"informational HUD regions do not swallow chopping clicks outside Pause")

	var first_span := run.get_xp_to_next_level_for_xp(0)
	var awarded := run.award_xp(first_span)
	_check(awarded == first_span and run.get_level() == 2 \
		and run.get_current_offer().is_empty() and not run.is_paused(),
		"authoritative level gain does not pause before its displayed bar event")
	await get_tree().process_frame
	await get_tree().process_frame
	var offer := run.get_current_offer()
	var first_ids := _card_ids(offer)
	var offer_overlay := hud.get_node("RunPowerOffer") as Control
	var cards_row := offer_overlay.find_child("Cards", true, false) as HBoxContainer
	_check(int(offer.get("level", 0)) == 2 and first_ids.size() == 3 \
		and _all_distinct(first_ids) and run.is_paused() \
		and game.process_mode == Node.PROCESS_MODE_DISABLED \
		and offer_overlay.visible and cards_row.get_child_count() == 3,
		"displayed Level 2 opens three distinct Core cards and pauses the production run")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_capture_if_rendered("/private/tmp/axeman_run_power_offer.png")
	_check(not run.choose_run_offer(&"not_an_offer"),
		"an unoffered power cannot be selected")

	var charges := run.get_utility_charges()
	_check(int(charges.get("rerolls", 0)) == 1 \
		and int(charges.get("banishes", 0)) == 3,
		"run-start utility charges match the purchased permanent ranks")
	var reroll_button := _find_button_with_prefix(offer_overlay, "REROLL")
	var reroll_before := int(run.get_utility_charges().get("rerolls", -1))
	reroll_button.pressed.emit()
	_check(reroll_before == 1 \
		and int(run.get_utility_charges().get("rerolls", -1)) == 0,
		"the visible Reroll button consumes the current choice event's charge")
	var rerolled := run.get_current_offer()
	var rerolled_ids := _card_ids(rerolled)
	_check(rerolled_ids.size() == 3 and _all_distinct(rerolled_ids) \
		and _sets_disjoint(first_ids, rerolled_ids) \
		and int(run.get_utility_charges().get("rerolls", -1)) == 0,
		"reroll preserves card count, replaces all cards, and consumes one charge")
	var first_banish := rerolled_ids[0]
	var second_banish := rerolled_ids[1]
	_check(run.banish_run_offer(first_banish) \
		and run.banish_run_offer(second_banish),
		"banish removes selected cards without replacement")
	var one_card := run.get_current_offer()
	var one_id := _card_ids(one_card)[0]
	_check(_card_ids(one_card).size() == 1 \
		and not run.banish_run_offer(one_id) \
		and int(run.get_utility_charges().get("banishes", -1)) == 1,
		"the final remaining card cannot be banished or spend a charge")
	await get_tree().process_frame
	var choose_button := _find_button_with_text(offer_overlay, "CHOOSE")
	choose_button.pressed.emit()
	_check(run.get_power_slots() == [one_id] \
		and run.get_run_power_rank(one_id) == 1 and not run.is_paused() \
		and not offer_overlay.visible,
		"the visible Choose button fills one stable slot and resumes the run")

	var yard := SurvivorsContent.yards().by_id(GameState.get_selected_yard())
	var to_level_four := yard.total_xp_for_level(4) - run.get_xp()
	_check(run.award_xp(to_level_four) == to_level_four \
		and run.get_level() == 4 and run.get_current_offer().is_empty(),
		"a multi-level authoritative award remains unpresented for the current frame")
	await get_tree().process_frame
	await get_tree().process_frame
	var level_three_offer := run.get_current_offer()
	_check(int(level_three_offer.get("level", 0)) == 3 and run.is_paused() \
		and (run.to_save_dict().get("ready_level_choices", []) as Array) == [4],
		"multiple displayed levels queue and expose only the first choice")
	var level_three_pick := _card_ids(level_three_offer)[0]
	_check(run.choose_run_offer(level_three_pick) \
		and int(run.get_current_offer().get("level", 0)) == 4 \
		and run.is_paused(),
		"choosing the first queued level immediately opens the next while paused")
	var level_four_pick := _card_ids(run.get_current_offer())[0]
	_check(run.choose_run_offer(level_four_pick) \
		and run.get_current_offer().is_empty() and not run.is_paused(),
		"the run resumes only after every queued level choice resolves")

	var to_level_five := yard.total_xp_for_level(5) - run.get_xp()
	run.award_xp(to_level_five)
	await get_tree().process_frame
	await get_tree().process_frame
	var saved_offer := run.get_current_offer()
	var snapshot := run.to_save_dict()
	var saved_rng_state := int(snapshot.get("rng_state", 0))
	_check(not saved_offer.is_empty() and run.restore_attempt(snapshot) \
		and run.get_current_offer() == saved_offer \
		and int(run.to_save_dict().get("rng_state", -1)) == saved_rng_state,
		"suspend data restores the exact active cards and RNG state without rerolling")
	run.resume_attempt()
	_check(run.is_paused() and run.get_current_offer() == saved_offer \
		and offer_overlay.visible,
		"public resume cannot bypass an unresolved restored offer")
	var restored_pick := _card_ids(saved_offer)[0]
	_check(run.choose_run_offer(restored_pick) and not run.is_paused(),
		"the restored offer remains selectable and releases its pause")

	# Fill remaining slots through real level events. Prefer a new card whenever
	# one is offered; selected ranks remain legal when a level rolls only repeats.
	var safety := 0
	while run.get_power_slots().size() < RunDirector.MAX_RUN_POWER_SLOTS \
			and safety < 24:
		safety += 1
		var next_award := run.get_xp_to_next_level_for_xp(run.get_xp())
		run.award_xp(next_award)
		await get_tree().process_frame
		await get_tree().process_frame
		var loop_offer := run.get_current_offer()
		var loop_ids := _card_ids(loop_offer)
		var pick := loop_ids[0]
		for candidate: StringName in loop_ids:
			if candidate not in run.get_power_slots():
				pick = candidate
				break
		run.choose_run_offer(pick)
	_check(run.get_power_slots().size() == RunDirector.MAX_RUN_POWER_SLOTS,
		"temporary powers fill all six run slots through production choices")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_capture_if_rendered("/private/tmp/axeman_run_six_slots.png")
	var after_six_award := run.get_xp_to_next_level_for_xp(run.get_xp())
	run.award_xp(after_six_award)
	await get_tree().process_frame
	await get_tree().process_frame
	var after_six_ids := _card_ids(run.get_current_offer())
	var selected_only := not after_six_ids.is_empty()
	for power_id: StringName in after_six_ids:
		selected_only = selected_only and power_id in run.get_power_slots()
	_check(selected_only,
		"after six slots, later offers contain only ranks for selected powers")
	if not after_six_ids.is_empty():
		run.choose_run_offer(after_six_ids[0])

	main.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_SAVE_PATH))
	SaveSystem.reset_save_path_after_tests()


func _find_four_card_luck_seed(run: RunDirector, hud: YardHUD) -> int:
	var offer_overlay := hud.get_node("RunPowerOffer") as Control
	var cards_row := offer_overlay.find_child("Cards", true, false) as HBoxContainer
	for seed: int in range(1, 65):
		run.start_attempt(seed)
		var first_span := run.get_xp_to_next_level_for_xp(0)
		run.award_xp(first_span)
		await get_tree().process_frame
		await get_tree().process_frame
		var offer := run.get_current_offer()
		var ids := _card_ids(offer)
		if int(offer.get("slot_count", 0)) == RunDirector.LUCK_OFFER_CARD_COUNT \
				and ids.size() == RunDirector.LUCK_OFFER_CARD_COUNT \
				and _all_distinct(ids) and run.is_paused() \
				and offer_overlay.visible \
				and cards_row.get_child_count() == RunDirector.LUCK_OFFER_CARD_COUNT:
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				_capture_if_rendered("/private/tmp/axeman_run_power_offer_four.png")
			return seed
		run.abandon_attempt()
		await get_tree().process_frame
	return -1


func _card_ids(offer: Dictionary) -> Array[StringName]:
	var ids: Array[StringName] = []
	var raw_cards: Variant = offer.get("cards", [])
	if raw_cards is Array:
		for raw_card: Variant in raw_cards:
			if raw_card is Dictionary:
				ids.append(StringName((raw_card as Dictionary).get("id", "")))
	return ids


func _all_distinct(ids: Array[StringName]) -> bool:
	var seen: Dictionary = {}
	for id: StringName in ids:
		if id == &"" or seen.has(id):
			return false
		seen[id] = true
	return true


func _sets_disjoint(left: Array[StringName], right: Array[StringName]) -> bool:
	for id: StringName in left:
		if id in right:
			return false
	return true


func _find_button_with_text(root: Node, text: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == text and not button.is_queued_for_deletion():
			return button
	return null


func _find_button_with_prefix(root: Node, prefix: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text.begins_with(prefix) \
				and not button.is_queued_for_deletion():
			return button
	return null


func _capture_if_rendered(path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	_check(image != null and image.get_width() == 1280 \
		and image.get_height() == 720 and image.save_png(path) == OK,
		"rendered power-choice checkpoint is 1280x720: %s" % path)


func _on_watchdog() -> void:
	if _completed:
		return
	push_error("FAIL: run-power offer scenario timed out")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_SAVE_PATH))
	SaveSystem.reset_save_path_after_tests()
	get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + message)
	else:
		_fails += 1
		push_error("FAIL: " + message)
