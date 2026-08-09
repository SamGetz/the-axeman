extends Node
## Focused first-time tutorial, dialogue, persistence and placeholder-art checks.

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== TUTORIAL ACCEPTANCE — First Yard Guidance ===")
	await _test_content_and_art()
	await _test_opening_flow_and_persistence()
	await _test_skip_is_persisted_and_non_granting()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	print("=== TUTORIAL RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL TUTORIAL AND PLACEHOLDER-ART CRITERIA PASS ===")
	get_tree().quit(1 if _fails > 0 else 0)


func _test_content_and_art() -> void:
	var content := load("res://data/tutorial_content.tres") as TutorialTable
	_check(content != null and content.validate().is_empty() \
		and content.guides.size() == 3 and content.beats.size() == 16 \
		and is_equal_approx(content.event_delay_seconds, 2.0),
		"three typed mentors, sixteen beats, and the two-second presentation delay validate")
	var plain_and_concise := true
	var action_driven := 0
	var forbidden_system_words := ["actionable", "authoritative", "gate",
		"lifetime", "log-equivalent", "receipt"]
	for beat: TutorialBeatDef in content.beats:
		var combined := (beat.dialogue + " " + beat.objective).to_lower()
		plain_and_concise = plain_and_concise \
			and beat.dialogue.split(" ", false).size() <= 30 \
			and beat.objective.split(" ", false).size() <= 16
		for word: String in forbidden_system_words:
			plain_and_concise = plain_and_concise and not combined.contains(word)
		if beat.completion_kind != TutorialBeatDef.CompletionKind.ACKNOWLEDGE:
			action_driven += 1
	_check(plain_and_concise,
		"every instruction is short, literal and free of implementation language")
	_check(action_driven >= 13 \
		and content.opening_beats()[0].completion_kind == \
			TutorialBeatDef.CompletionKind.HUD_ACTION,
		"the guide advances mostly from real play and starts at the first new button")
	var portrait_ok := true
	for guide: TutorialGuideDef in content.guides:
		var portrait := load(guide.portrait_path) as Texture2D
		portrait_ok = portrait_ok and portrait != null \
			and portrait.get_width() >= 512 and portrait.get_height() >= 512
	_check(portrait_ok,
		"Rowan, Ada and Nova each have a readable project-local generated portrait")
	var placeholder_paths := [
		"res://assets/ui/placeholders/supplier_ledger.svg",
		"res://assets/ui/placeholders/handcart.svg",
		"res://assets/ui/placeholders/coffee_thermos.svg",
		"res://assets/ui/placeholders/mechanical_splitter.svg",
		"res://assets/ui/placeholders/craft_grade.svg",
		"res://assets/ui/placeholders/active_delivery.svg",
		"res://assets/ui/placeholders/delivery_stamp.svg",
	]
	_check(placeholder_paths.all(func(path: String) -> bool:
		return load(path) is Texture2D),
		"every audited missing equipment and delivery graphic has a loadable placeholder")


func _test_opening_flow_and_persistence() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var starting_cash := GameState.get_cash()
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	var director: TutorialDirector = hud.call("tutorial_director")
	director.begin_for_session(true, hud)
	var opening_cost := Shop.opening_unlock_cost()
	_check(not director.is_showing_tip() and director.active_beat_id() == &"" \
		and not (hud.get_node("QuickMenu/ShopButton") as Button).visible \
		and not (hud.get_node("QuickMenu/TreesButton") as Button).visible \
		and not (hud.get_node("QuickMenu/SkillsButton") as Button).visible \
		and not (hud.get_node("QuickMenu/AtlasButton") as Button).visible,
		"a fresh yard leaves the log unobstructed while future buttons stay hidden")
	var fresh_visible_copy := _visible_text_under(hud)
	_check(not fresh_visible_copy.contains("Aspen Hearth") \
		and not fresh_visible_copy.contains("Supplier Ledger") \
		and not fresh_visible_copy.contains("Handcart") \
		and not fresh_visible_copy.contains("Eastern White Pine"),
		"the fresh HUD does not advertise future contract, item or species identities")
	GameState.award_cash(opening_cost, &"tutorial_acceptance")
	await get_tree().process_frame
	_check(director.active_beat_id() == &"" and not director.is_showing_tip() \
		and not (hud.get_node("QuickMenu/ShopButton") as Button).visible \
		and not (hud.get_node("QuickMenu/OrdersButton") as Button).visible,
		"affording an item does not reveal either Jobs or Shop")
	GameState.award_xp(GameState.get_xp_to_next_level(), &"tutorial_acceptance")
	_check(not director.is_showing_tip(),
		"the Skills lesson stays hidden immediately after its unlock event")
	await get_tree().process_frame
	await get_tree().create_timer(2.1).timeout
	await get_tree().process_frame
	_check(director.active_beat_id() == &"skills" and director.is_showing_tip() \
		and (hud.get_node("QuickMenu/SkillsButton") as Button).visible \
		and not (hud.get_node("QuickMenu/OrdersButton") as Button).visible \
		and not (hud.get_node("QuickMenu/ShopButton") as Button).visible \
		and not (hud.get_node("QuickMenu/TreesButton") as Button).visible,
		"level 2 restores the Skills lesson while Jobs and Shop remain locked")
	# The shipping two-second path is verified above. Keep the remaining sixteen-
	# beat behavioural walk fast while exercising the same timer implementation.
	(load("res://data/tutorial_content.tres") as TutorialTable).event_delay_seconds = 0.04
	_press(director, "Card/Margin/Row/Copy/Actions/Close")
	await get_tree().process_frame
	_check(not director.is_showing_tip() and director.active_beat_id() == &"skills" \
		and (director.get_node("HelpButton") as Button).visible,
		"Close gets the tutorial card out of the way without skipping its lesson")
	_press(director, "HelpButton")
	await get_tree().process_frame
	_check(director.is_showing_tip() and director.active_beat_id() == &"skills",
		"the help button reopens the current closed lesson")
	_press(hud, "QuickMenu/SkillsButton")
	await get_tree().process_frame
	_check(director.active_beat_id() == &"skill_spend" \
		and not director.is_showing_tip(),
		"opening Skills queues its follow-up without stacking another dialog")
	await get_tree().create_timer(0.07).timeout
	await get_tree().process_frame
	_check(director.is_showing_tip() and director.active_beat_id() == &"skill_spend",
		"the follow-up lesson appears only after the shared event delay")
	_check(SkillTree.buy(&"strong_arms"),
		"the test player spends a point on a visible root")
	await get_tree().process_frame
	_check(director.active_beat_id() == &"",
		"spending the point completes the restored early Skills lesson")
	_press(hud, "SkillPanel/Column/CloseSkillButton")
	GameState.award_xp(GameState.get_xp_to_next_level(), &"tutorial_acceptance")
	var expected_xp := GameState.get_xp()
	await get_tree().process_frame
	_check(director.active_beat_id() == &"open_orders" \
		and (hud.get_node("QuickMenu/OrdersButton") as Button).visible \
		and not (hud.get_node("QuickMenu/ShopButton") as Button).visible \
		and not (hud.get_node("QuickMenu/TreesButton") as Button).visible \
		and (hud.get_node("QuickMenu/SkillsButton") as Button).visible,
		"level 3 reveals Jobs and starts its guide while Shop stays hidden")
	_press(hud, "QuickMenu/OrdersButton")
	await get_tree().process_frame
	_check(director.active_beat_id() == &"orders_reading",
		"the open board asks the player to finish the first visible job")
	var first_order := Orders.by_id(&"campfire_warmup")
	_check(first_order != null and GameState.accept_order(first_order.id),
		"the test player accepts the first visible delivery")
	await get_tree().process_frame
	_check(director.active_beat_id() == &"orders_reading" \
		and not (hud.get_node("QuickMenu/ShopButton") as Button).visible,
		"accepting alone leaves the Shop locked and keeps the delivery guidance active")
	_press(hud, "OrdersPanel/Column/CloseButton")
	for _piece in range(first_order.required_count):
		GameState.record_order_piece(&"birch_firewood")
	await get_tree().process_frame
	_check(director.active_beat_id() == &"open_shop" \
		and (hud.get_node("QuickMenu/ShopButton") as Button).visible \
		and not (hud.get_node("QuickMenu/TreesButton") as Button).visible,
		"completing the job reveals Shop while Catalog remains later")
	_press(hud, "QuickMenu/ShopButton")
	await get_tree().process_frame
	_check(director.active_beat_id() == &"shop_reading",
		"opening the Shop asks for one real 50-coin purchase")
	var first_upgrade := Shop.get_upgrades()[0] as UpgradeDef
	_check(first_upgrade != null and Shop.buy(first_upgrade.id) > 0,
		"the test player buys one visible opening upgrade")
	await get_tree().process_frame
	_check(director.active_beat_id() == &"opening_complete",
		"buying either upgrade advances without a separate equip step")
	await get_tree().create_timer(0.07).timeout
	_press(director, "Card/Margin/Row/Copy/Actions/Continue")
	await get_tree().process_frame
	_check(GameState.has_introduced_feature(&"tutorial_opening_complete") \
		and director.active_beat_id() == &"" \
		and GameState.get_cash() == starting_cash + first_order.cash_bonus \
		and GameState.get_xp() == expected_xp \
		and GameState.get_manual_log_equivalents() == 0,
		"the paced guide observes play without inventing cash, XP or logs")
	_press(hud, "ShopPanel/Column/CloseShopButton")
	await get_tree().process_frame
	GameState.award_xp(GameState.get_xp_to_next_level(), &"tutorial_acceptance")
	EventBus.building_upgraded.emit(&"supplier_ledger",
		GameState.DEFAULT_BUILDING_TIER + 1)
	var next_wood := GameState.get_next_unowned_species()
	GameState.award_cash(next_wood.unlock_cost, &"tutorial_acceptance")
	await get_tree().process_frame
	_check((hud.get_node("QuickMenu/TreesButton") as Button).visible \
		and director.active_beat_id() == &"open_catalog",
		"an affordable new wood highlights the round log button (tip=%s visible=%s)" % [
			director.active_beat_id(),
			(hud.get_node("QuickMenu/TreesButton") as Button).visible])
	_press(hud, "QuickMenu/TreesButton")
	await get_tree().process_frame
	_check(director.active_beat_id() == &"catalog_pick",
		"opening the wood list asks for the clearly priced new wood (tip=%s)" % \
			director.active_beat_id())
	_check(GameState.try_buy_species(next_wood.id),
		"the test player buys the newly available wood")
	await get_tree().process_frame
	_check(director.active_beat_id() == &"",
		"buying the wood completes the Catalog lesson (tip=%s)" % \
			director.active_beat_id())
	var snapshot := GameState.to_save_dict()
	hud.queue_free()
	await get_tree().process_frame
	GameState.reset_to_defaults()
	GameState.apply_save_dict(snapshot)
	var restored_hud: Control = load(
		"res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(restored_hud)
	var restored: TutorialDirector = restored_hud.call("tutorial_director")
	restored.begin_for_session(false, restored_hud)
	_check(restored.active_beat_id() == &"" and not restored.is_showing_tip(),
		"completed tutorial beats restore without replaying or revealing gated later systems")
	restored_hud.queue_free()
	await get_tree().process_frame


func _test_skip_is_persisted_and_non_granting() -> void:
	GameState.reset_to_defaults()
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	var director: TutorialDirector = hud.call("tutorial_director")
	director.begin_for_session(true, hud)
	var curve := GameConfig.current().level_curve
	GameState.award_xp(curve.total_xp_for_level(Orders.JOBS_UNLOCK_LEVEL),
		&"tutorial_acceptance")
	await get_tree().create_timer(0.07).timeout
	var cash_before := GameState.get_cash()
	var xp_before := GameState.get_xp()
	_press(director, "Card/Margin/Row/Copy/Actions/Skip")
	await get_tree().process_frame
	_check(GameState.has_introduced_feature(&"tutorial_all_skipped") \
		and not director.is_showing_tip() \
		and (hud.get_node("QuickMenu/ShopButton") as Button).visible == \
			Shop.is_entry_revealed() \
		and GameState.get_cash() == cash_before \
		and GameState.get_xp() == xp_before \
		and GameState.get_manual_log_equivalents() == 0,
		"skipping is persisted, closes all future tips, and cannot alter progression")
	hud.queue_free()
	await get_tree().process_frame


func _press(root: Node, path: NodePath) -> void:
	var button := root.get_node(path) as Button
	button.pressed.emit()


func _visible_text_under(root: Node) -> String:
	var result := ""
	for node: Node in root.find_children("*", "Label", true, false):
		var label := node as Label
		if label.is_visible_in_tree():
			result += label.text + "\n"
	for node: Node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.is_visible_in_tree():
			result += button.text + "\n"
	return result


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)
