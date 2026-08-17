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
	var offer_overlay := hud.get_node("RunPowerOffer") as Control
	var offer_rain := offer_overlay.find_child(
		"LevelChoiceDecor", true, false) as Control
	var offer_rain_id := 0 if offer_rain == null else offer_rain.get_instance_id()
	var rain_idle_state := _rain_state(offer_rain)
	_check(offer_rain != null and not offer_overlay.visible \
		and not offer_rain.visible \
		and not bool(rain_idle_state.get("active", true)) \
		and not bool(rain_idle_state.get("processing", true)),
		"the persistent level-choice rain is stopped and hidden without an offer")
	var game := main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/Chopping_Minigame")
	game.set("orbs_enabled", false)
	var luck_seed := await _find_four_card_luck_seed(run, hud)
	_check(luck_seed > 0,
		"max-rank Luck opens four distinct cards in the production offer UI")
	var luck_rain_state := _rain_state(offer_rain)
	_check(offer_rain.get_instance_id() == offer_rain_id \
		and offer_rain.visible and bool(luck_rain_state.get("active", false)),
		"the production four-card offer activates the persistent level-choice rain")
	run.abandon_attempt()
	await get_tree().process_frame
	var abandoned_rain_state := _rain_state(offer_rain)
	_check(run.get_run_id() == &"" and offer_rain.get_instance_id() == offer_rain_id \
		and not offer_overlay.visible and not offer_rain.visible \
		and not bool(abandoned_rain_state.get("active", true)) \
		and not bool(abandoned_rain_state.get("processing", true)) \
		and int(abandoned_rain_state.get("allocated", 0)) \
			== int(luck_rain_state.get("allocated", -1)),
		"abandon and its cleared run identity stop the rain without freeing its pool")
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
	var close_button := _find_button_with_text(pause_backdrop, "RESUME RUN")
	var suspend_button := _find_button_with_text(pause_backdrop,
		"SUSPEND THIS ATTEMPT")
	var abandon_button := _find_button_with_text(pause_backdrop,
		"ABANDON ATTEMPT")
	_check(run.is_paused() and pause_backdrop.visible and close_button != null \
		and suspend_button != null and not suspend_button.pressed.get_connections().is_empty() \
		and abandon_button != null and not abandon_button.pressed.get_connections().is_empty(),
		"Pause, Resume, Suspend, and Abandon controls are visible and connected")
	var paused_rain_state := _rain_state(offer_rain)
	_check(not offer_overlay.visible and not offer_rain.visible \
		and not bool(paused_rain_state.get("active", true)),
		"ordinary Pause does not show level-choice rain when there is no offer")
	close_button.pressed.emit()
	await get_tree().process_frame
	_check(not run.is_paused() and not pause_backdrop.visible,
		"the production Resume button resumes the paused run")
	var xp_bar := hud.get_node("XPBar") as Control
	var cash_counter := hud.get_node("CashCounter") as Control
	var power_slots_control := hud.get_node("RunPowerSlots") as Control
	_check(xp_bar.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and cash_counter.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and power_slots_control.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and quick_menu.size.x <= 100.0,
		"informational HUD regions do not swallow chopping clicks outside Pause")
	var xp_rect := xp_bar.get_global_rect()
	var slots_rect := power_slots_control.get_global_rect()
	var compact_slots := power_slots_control.get_child_count() \
		== RunDirector.MAX_RUN_POWER_SLOTS
	for raw_slot: Node in power_slots_control.get_children():
		var slot := raw_slot as Control
		compact_slots = compact_slots and slot != null \
			and slot.size.x <= 56.01 and slot.size.y <= 42.01
	_check(compact_slots and power_slots_control.anchor_top == 0.0 \
		and power_slots_control.anchor_left == 0.5 \
		and power_slots_control.anchor_right == 0.5 \
		and slots_rect.position.y >= xp_rect.end.y + 4.0 \
		and slots_rect.size.x <= 356.01 and slots_rect.size.y <= 42.01 \
		and is_equal_approx(slots_rect.get_center().x,
			get_viewport().get_visible_rect().get_center().x),
		"the compact six-slot loadout is centered directly below the XP bar")

	var first_span := run.get_xp_to_next_level_for_xp(0)
	var awarded := run.award_xp(first_span)
	_check(awarded == int(round(float(first_span) \
			* run.tuning.global_xp_gain_multiplier)) and run.get_level() == 2 \
		and run.get_current_offer().is_empty() and not run.is_paused(),
		"the globally boosted authoritative level gain does not pause before its displayed bar event")
	await get_tree().process_frame
	await get_tree().process_frame
	var offer := run.get_current_offer()
	var first_ids := _card_ids(offer)
	var cards_row := offer_overlay.find_child("Cards", true, false) as VBoxContainer
	var rain_before_tick := _rain_state(offer_rain)
	await get_tree().process_frame
	await get_tree().process_frame
	var rain_after_tick := _rain_state(offer_rain)
	_check(int(offer.get("level", 0)) == 2 and first_ids.size() == 3 \
		and _all_distinct(first_ids) and run.is_paused() \
		and game.process_mode == Node.PROCESS_MODE_DISABLED \
		and offer_overlay.visible and cards_row.get_child_count() == 3,
		"displayed Level 2 opens three distinct Core cards and pauses the production run")
	var choose_buttons := _visible_buttons_with_text(offer_overlay, "CHOOSE")
	var cards_are_vertical := cards_row != null
	for index: int in range(1, cards_row.get_child_count() if cards_row != null else 0):
		var previous := cards_row.get_child(index - 1) as Control
		var current := cards_row.get_child(index) as Control
		cards_are_vertical = cards_are_vertical and previous != null and current != null \
			and current.global_position.y > previous.global_position.y \
			and is_equal_approx(current.size.x, previous.size.x)
	_check(choose_buttons.size() == 3 and cards_are_vertical \
		and get_viewport().gui_get_focus_owner() == choose_buttons[0],
		"the level-up menu presents equal-width vertical choices and focuses the first one")
	_check(offer_rain.get_instance_id() == offer_rain_id and offer_rain.visible \
		and offer_rain.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and offer_rain.process_mode == Node.PROCESS_MODE_ALWAYS \
		and bool(rain_after_tick.get("active", false)) \
		and bool(rain_after_tick.get("processing", false)) \
		and int(rain_after_tick.get("animation_tick", 0)) \
			> int(rain_before_tick.get("animation_tick", -1)) \
		and int(rain_after_tick.get("allocated", 0)) >= 3 \
		and int(rain_after_tick.get("live", 0)) \
			== int(rain_after_tick.get("allocated", -1)) \
		and int(rain_after_tick.get("trees", 0)) > 0 \
		and int(rain_after_tick.get("logs", 0)) > 0 \
		and int(rain_after_tick.get("leaves", 0)) > 0,
		"input-transparent tree, log, and leaf rain animates while its offer pauses gameplay")
	var rain_clip := offer_rain.get_parent() as Control
	var expected_rain_rect := cards_row.get_global_rect()
	var actual_clip_rect := rain_clip.get_global_rect() if rain_clip != null else Rect2()
	var active_rain_rect: Rect2 = rain_after_tick.get("effect_rect", Rect2())
	# Card minimum sizes can finish shaping a few pixels after the deferred rect
	# sync. Pin the real clip origin/width exactly and allow that bounded vertical
	# layout settling without coupling the acceptance test to a font RID frame.
	_check(rain_clip != null and rain_clip.clip_contents \
		and actual_clip_rect.position.is_equal_approx(expected_rain_rect.position) \
		and is_equal_approx(actual_clip_rect.size.x, expected_rain_rect.size.x) \
		and absf(actual_clip_rect.size.y - expected_rain_rect.size.y) <= 12.0 \
		and active_rain_rect.position.is_equal_approx(Vector2.ZERO) \
		and active_rain_rect.size.is_equal_approx(offer_rain.size) \
		and offer_rain.size.is_equal_approx(rain_clip.size) \
		and active_rain_rect.size.x > 1.0 and active_rain_rect.size.y > 1.0 \
		and active_rain_rect.size.y < offer_overlay.size.y,
		"level-choice rain is clipped to the live card band rather than the full modal")
	var offer_before_hide := run.get_current_offer().duplicate(true)
	hud.hide()
	await get_tree().process_frame
	var hidden_rain_state := _rain_state(offer_rain)
	_check(not hud.is_visible_in_tree() and run.get_current_offer() == offer_before_hide \
		and not offer_overlay.visible and not offer_rain.visible \
		and not bool(hidden_rain_state.get("active", true)) \
		and not bool(hidden_rain_state.get("processing", true)),
		"hiding the run HUD stops ALWAYS-mode offer rain without consuming the choice")
	hud.show()
	await get_tree().process_frame
	await get_tree().process_frame
	var shown_rain_state := _rain_state(offer_rain)
	_check(hud.is_visible_in_tree() and run.get_current_offer() == offer_before_hide \
		and offer_overlay.visible and offer_rain.visible \
		and offer_rain.get_instance_id() == offer_rain_id \
		and bool(shown_rain_state.get("active", false)) \
		and bool(shown_rain_state.get("processing", false)) \
		and int(shown_rain_state.get("allocated", 0)) \
			== int(rain_after_tick.get("allocated", -1)),
		"showing a pending offer restarts the same clipped rain pool and exact cards")
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
	var rerolled_rain_state := _rain_state(offer_rain)
	_check(rerolled_ids.size() == 3 and _all_distinct(rerolled_ids) \
		and _sets_disjoint(first_ids, rerolled_ids) \
		and int(run.get_utility_charges().get("rerolls", -1)) == 0,
		"reroll preserves card count, replaces all cards, and consumes one charge")
	_check(offer_rain.get_instance_id() == offer_rain_id \
		and bool(rerolled_rain_state.get("active", false)) \
		and int(rerolled_rain_state.get("allocated", 0)) \
			== int(rain_after_tick.get("allocated", -1)),
		"reroll reuses the same active rain node and fixed-size drop pool")
	# Quick Study scales every later XP award. This offer suite is exercising
	# level-event/UI sequencing, so keep a different card and leave the quality-
	# scaled XP contract to the dedicated runtime gate.
	var kept_id := _non_quick_study_pick(rerolled_ids)
	var banished_ids: Array[StringName] = []
	for candidate: StringName in rerolled_ids:
		if candidate != kept_id:
			banished_ids.append(candidate)
	var first_banish := banished_ids[0]
	var second_banish := banished_ids[1]
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
	var banished_rain_state := _rain_state(offer_rain)
	_check(offer_rain.get_instance_id() == offer_rain_id \
		and bool(banished_rain_state.get("active", false)) \
		and int(banished_rain_state.get("allocated", 0)) \
			== int(rain_after_tick.get("allocated", -1)),
		"banish rebuilds the cards while preserving the active rain node and pool")
	var choose_button := _find_button_with_text(offer_overlay, "CHOOSE")
	choose_button.pressed.emit()
	var selected_rain_state := _rain_state(offer_rain)
	_check(run.get_power_slots() == [one_id] \
		and run.get_run_power_rank(one_id) == 1 and not run.is_paused() \
		and not offer_overlay.visible,
		"the visible Choose button fills one stable slot and resumes the run")
	_check(not offer_rain.visible and not bool(selected_rain_state.get("active", true)) \
		and not bool(selected_rain_state.get("processing", true)),
		"selecting the last presented choice immediately stops its rain")

	var yard := SurvivorsContent.yards().by_id(GameState.get_selected_yard())
	var to_level_four := yard.total_xp_for_level(4) - run.get_xp()
	_check(run.award_xp(to_level_four) == int(round(float(to_level_four) \
			* run.tuning.global_xp_gain_multiplier)) \
		and run.get_level() == 4 and run.get_current_offer().is_empty(),
		"a multi-level authoritative award remains unpresented for the current frame")
	await get_tree().process_frame
	await get_tree().process_frame
	var level_three_offer := run.get_current_offer()
	var queued_rain_state := _rain_state(offer_rain)
	_check(int(level_three_offer.get("level", 0)) == 3 and run.is_paused() \
		and (run.to_save_dict().get("ready_level_choices", []) as Array) == [4],
		"multiple displayed levels queue and expose only the first choice")
	_check(offer_rain.get_instance_id() == offer_rain_id \
		and bool(queued_rain_state.get("active", false)),
		"the first queued level reuses and activates the persistent rain node")
	var level_three_pick := _non_quick_study_pick(_card_ids(level_three_offer))
	_check(run.choose_run_offer(level_three_pick) \
		and int(run.get_current_offer().get("level", 0)) == 4 \
		and run.is_paused() and offer_rain.get_instance_id() == offer_rain_id \
		and bool(_rain_state(offer_rain).get("active", false)),
		"choosing the first queued level immediately opens the next while paused")
	var level_four_pick := _non_quick_study_pick(
		_card_ids(run.get_current_offer()))
	_check(run.choose_run_offer(level_four_pick) \
		and run.get_current_offer().is_empty() and not run.is_paused() \
		and not offer_rain.visible \
		and not bool(_rain_state(offer_rain).get("active", true)),
		"the run resumes only after every queued level choice resolves")

	var to_level_five := yard.total_xp_for_level(5) - run.get_xp()
	run.award_xp(to_level_five)
	await get_tree().process_frame
	await get_tree().process_frame
	var saved_offer := run.get_current_offer()
	var snapshot := run.to_save_dict()
	var saved_rng_state := int(snapshot.get("rng_state", 0))
	var pre_restore_rain_id := offer_rain.get_instance_id()
	_check(not saved_offer.is_empty() and run.restore_attempt(snapshot) \
		and run.get_current_offer() == saved_offer \
		and int(run.to_save_dict().get("rng_state", -1)) == saved_rng_state \
		and offer_rain.get_instance_id() == pre_restore_rain_id \
		and pre_restore_rain_id == offer_rain_id \
		and bool(_rain_state(offer_rain).get("active", false)),
		"suspend data restores the exact active cards and RNG state without rerolling")
	run.resume_attempt()
	_check(run.is_paused() and run.get_current_offer() == saved_offer \
		and offer_overlay.visible,
		"public resume cannot bypass an unresolved restored offer")
	var restored_pick := _non_quick_study_pick(_card_ids(saved_offer))
	_check(run.choose_run_offer(restored_pick) and not run.is_paused() \
		and not offer_rain.visible \
		and not bool(_rain_state(offer_rain).get("active", true)),
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
		var pick := _non_quick_study_pick(loop_ids, run.get_power_slots())
		run.choose_run_offer(pick)
	_check(run.get_power_slots().size() == RunDirector.MAX_RUN_POWER_SLOTS,
		"temporary powers fill all six run slots through production choices")
	var presented_icons := 0
	var icon_and_rank_only := true
	for raw_slot: Node in power_slots_control.get_children():
		var icon := raw_slot.find_child("Icon", true, false) as TextureRect
		var rank := raw_slot.find_child("Rank", true, false) as Label
		var name_label := raw_slot.find_child("Name", true, false) as Label
		var status := raw_slot.find_child("Status", true, false) as Label
		if icon != null and icon.visible and icon.texture != null:
			presented_icons += 1
		icon_and_rank_only = icon_and_rank_only and rank != null and rank.visible \
			and rank.text.begins_with("R") and name_label != null \
			and not name_label.visible and status != null and not status.visible
	_check(presented_icons == RunDirector.MAX_RUN_POWER_SLOTS \
		and icon_and_rank_only,
		"all six active slots show only their distinct icon and power rank")
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
	var cards_row := offer_overlay.find_child("Cards", true, false) as VBoxContainer
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


func _rain_state(rain: Control) -> Dictionary:
	if rain == null or not rain.has_method("debug_state"):
		return {}
	var raw_state: Variant = rain.call("debug_state")
	return (raw_state as Dictionary).duplicate(true) \
		if raw_state is Dictionary else {}


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


func _non_quick_study_pick(ids: Array[StringName],
		owned: Array[StringName] = []) -> StringName:
	for id: StringName in ids:
		if id != &"quick_study" and id not in owned:
			return id
	for id: StringName in ids:
		if id != &"quick_study":
			return id
	return &"" if ids.is_empty() else ids[0]


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


func _visible_buttons_with_text(root: Node, text: String) -> Array[Button]:
	var buttons: Array[Button] = []
	for node: Node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == text and button.is_visible_in_tree() \
				and not button.is_queued_for_deletion():
			buttons.append(button)
	return buttons


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
