extends Node
## Production acceptance for the catalogue-driven Home hub. The suite boots
## the real Main scene around one isolated v19 profile, exercises UI controls,
## and verifies that Main persists every permanent transaction.

const _SAVE_PATH := "user://survivors_home_ui_acceptance.cfg"
const _WATCHDOG_SECONDS := 24.0
const _STARTING_HOME_CASH := 10_000

const _LIFETIME_STATS := {
	"roots_completed": 42,
	"cash_earned": 987,
	"runs_settled": 6,
	"bosses_defeated": 3,
	"haul_aways_completed": 2,
}
const _YARD_RECORD := {
	"attempts": 6,
	"clears": 2,
	"best_clear_ms": 1_045_000,
	"longest_endless_ms": 123_000,
	"highest_level": 31,
	"best_session_cash": 456,
}

var _passed := 0
var _failed := 0
var _completed := false
var _active_main: AxemanMain


func _ready() -> void:
	print("=== SURVIVORS HOME UI ACCEPTANCE ===")
	get_tree().create_timer(_WATCHDOG_SECONDS).timeout.connect(_on_watchdog)
	await _run_scenario()
	_completed = true
	_check(_completed, "the production Home scenario reached its completion sentinel")
	print("SURVIVORS HOME UI: %d passed, %d failed" % [_passed, _failed])
	_cleanup()
	get_tree().quit(0 if _failed == 0 else 1)


func _run_scenario() -> void:
	var isolated := SaveSystem.set_save_path_for_tests(_SAVE_PATH)
	_check(isolated,
		"the Home suite uses an isolated SaveSystem path")
	if not isolated:
		return
	_remove_save_files()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var initial_profile := GameState.to_save_dict()
	initial_profile["home_cash"] = _STARTING_HOME_CASH
	initial_profile["lifetime_stats"] = _LIFETIME_STATS.duplicate(true)
	initial_profile["yard_records"] = {"yard_one": _YARD_RECORD.duplicate(true)}
	GameState.apply_save_dict(initial_profile)
	_check(SaveSystem.clear_attempt_and_save(),
		"the isolated profile is durable before production Main boots")

	var first_main := await _spawn_main()
	var first_home := _home_from(first_main)
	_check(first_home != null and first_home.visible \
		and not first_main.has_started_session(),
		"production Main opens the loaded profile at Home")
	_check(_label_text(first_home, "HomeCashLabel") == "$10,000",
		"Home displays the saved permanent bank")
	var landing_start := _find_named(first_home, "YardTabButton") as Button
	var landing_stage := _find_named(first_home, "LandingStage") as Control
	var quick_start := _find_named(first_home, "QuickStartButton") as Button
	_check(landing_start != null and landing_start.visible \
		and landing_start.text == "START" \
		and quick_start != null and quick_start.visible \
		and landing_stage != null and landing_stage.visible \
		and _find_named(first_home, "StartRunButton") == null,
		"Home matches the landing hierarchy with START, Quick Start, and no run launch")
	landing_start.pressed.emit()
	await _wait_frames(2)
	var level_launch := _find_named(first_home, "LevelLaunchPanel") as Control
	var level_start := _find_named(first_home, "StartRunButton") as Button
	_check(level_launch != null and level_launch.visible \
		and level_start != null and level_start.visible \
		and not first_main.has_started_session(),
		"landing START opens Level Select and leaves the run dormant until START RUN")
	_test_catalogue_surfaces(first_home)
	_test_records(first_home)

	var meta := SurvivorsContent.meta_upgrades()
	var axe := meta.by_id(&"axe_power") if meta != null else null
	var frequency := meta.by_id(&"fall_frequency_control") if meta != null else null
	var axe_cost := axe.cost_for_rank(1) if axe != null else -1
	var frequency_cost := frequency.cost_for_rank(1) if frequency != null else -1
	_click_nav(first_home, "UpgradesTabButton")
	await _wait_frames(2)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_capture_if_rendered("/private/tmp/axeman_home_menu.png")
	var axe_buy := _find_named(first_home, "Buy_axe_power") as Button
	var frequency_buy := _find_named(
		first_home, "Buy_fall_frequency_control") as Button
	_check(axe_buy != null and frequency_buy != null \
		and not axe_buy.disabled and not frequency_buy.disabled,
		"affordable permanent lines expose enabled purchase controls")
	if axe_buy != null:
		axe_buy.pressed.emit()
	await _wait_frames(2)
	frequency_buy = _find_named(
		first_home, "Buy_fall_frequency_control") as Button
	if frequency_buy != null:
		frequency_buy.pressed.emit()
	await _wait_frames(3)
	var paid_total := axe_cost + frequency_cost
	_check(axe_cost > 0 and frequency_cost > 0 \
		and GameState.get_meta_upgrade_rank(&"axe_power") == 1 \
		and GameState.get_meta_upgrade_rank(&"fall_frequency_control") == 1 \
		and _ledger_is_exact(&"axe_power", axe_cost) \
		and _ledger_is_exact(&"fall_frequency_control", frequency_cost) \
		and GameState.get_home_cash() == _STARTING_HOME_CASH - paid_total,
		"Home purchases debit exact catalogue costs into the spend ledger")

	_click_nav(first_home, "YardTabButton")
	await _wait_frames(2)
	var frequency_buttons := _nodes_with_prefix(first_home, "FrequencyTier")
	var tier_zero := _find_named(first_home, "FrequencyTier0Button") as Button
	var tier_one := _find_named(first_home, "FrequencyTier1Button") as Button
	var tier_two := _find_named(first_home, "FrequencyTier2Button") as Button
	var tier_three := _find_named(first_home, "FrequencyTier3Button") as Button
	_check(frequency_buttons.size() == 4 and tier_zero != null \
		and tier_one != null and tier_two != null and tier_three != null,
		"Yard renders the default plus all three authored frequency tiers")
	_check(tier_zero != null and tier_zero.disabled \
		and tier_one != null and not tier_one.disabled \
		and tier_two != null and tier_two.disabled \
		and tier_three != null and tier_three.disabled,
		"one Fall Frequency Control rank unlocks exactly tier one")
	if tier_one != null:
		tier_one.pressed.emit()
	await _wait_frames(3)
	tier_zero = _find_named(first_home, "FrequencyTier0Button") as Button
	tier_one = _find_named(first_home, "FrequencyTier1Button") as Button
	_check(GameState.get_selected_frequency_tier() == 1 \
		and tier_zero != null and not tier_zero.disabled \
		and tier_one != null and tier_one.disabled,
		"the unlocked frequency tier is selectable through Home")

	await _dispose_main(first_main)
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var second_main := await _spawn_main()
	var second_home := _home_from(second_main)
	_check(GameState.get_home_cash() == _STARTING_HOME_CASH - paid_total \
		and GameState.get_meta_upgrade_rank(&"axe_power") == 1 \
		and GameState.get_meta_upgrade_rank(&"fall_frequency_control") == 1 \
		and _ledger_is_exact(&"axe_power", axe_cost) \
		and _ledger_is_exact(&"fall_frequency_control", frequency_cost) \
		and GameState.get_selected_frequency_tier() == 1,
		"a second production Main reloads Home cash, ranks, ledger, and frequency")

	_click_nav(second_home, "UpgradesTabButton")
	await _wait_frames(2)
	var refund_button := _find_button_prefix(second_home, "Refund All")
	var refund_signals: Array[int] = []
	GameState.meta_upgrades_refunded.connect(
		func(amount: int) -> void: refund_signals.append(amount),
		Object.CONNECT_ONE_SHOT)
	_check(refund_button != null and not refund_button.disabled \
		and refund_button.text.contains("$%s" % _format_number(paid_total)),
		"the free full-refund control exposes the exact invested amount")
	if refund_button != null:
		refund_button.pressed.emit()
	await _wait_frames(3)
	_check(refund_signals == [paid_total] \
		and GameState.get_home_cash() == _STARTING_HOME_CASH \
		and GameState.get_meta_upgrade_ranks().is_empty() \
		and GameState.get_meta_upgrade_spend_ledger().is_empty() \
		and GameState.get_selected_frequency_tier() == 0,
		"full refund returns the paid ledger exactly and clamps frequency")

	await _dispose_main(second_main)
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var third_main := await _spawn_main()
	var third_home := _home_from(third_main)
	_check(GameState.get_home_cash() == _STARTING_HOME_CASH \
		and GameState.get_meta_upgrade_ranks().is_empty() \
		and GameState.get_meta_upgrade_spend_ledger().is_empty() \
		and GameState.get_selected_frequency_tier() == 0,
		"the exact refund remains durable through another production Main boot")

	# Leave a genuinely useful purchase in place before suspension so each lock
	# assertion distinguishes suspended read-only state from ordinary gating.
	_click_nav(third_home, "UpgradesTabButton")
	await _wait_frames(2)
	frequency_buy = _find_named(
		third_home, "Buy_fall_frequency_control") as Button
	if frequency_buy != null:
		frequency_buy.pressed.emit()
	await _wait_frames(2)
	_click_nav(third_home, "YardTabButton")
	await _wait_frames(2)
	tier_one = _find_named(third_home, "FrequencyTier1Button") as Button
	if tier_one != null:
		tier_one.pressed.emit()
	await _wait_frames(2)
	var start_button := _find_named(third_home, "StartRunButton") as Button
	_check(start_button != null and start_button.visible and not start_button.disabled,
		"Home exposes Start Run when no suspended attempt exists")
	if start_button != null:
		start_button.pressed.emit()
	await _wait_frames(6)
	_check(third_main.has_started_session(),
		"the Home Start Run control enters production play")
	third_main.call("_suspend_to_title")
	await _wait_frames(8)
	third_home = _home_from(third_main)
	_test_suspended_lock(third_home, frequency_cost)


func _test_catalogue_surfaces(home: StartupMenu) -> void:
	_click_nav(home, "UpgradesTabButton")
	var meta := SurvivorsContent.meta_upgrades()
	var upgrade_grid := _find_named(home, "PowerUpGrid") as GridContainer
	var detail := _find_named(home, "SelectedUpgradeDetail") as Control
	var back := _find_named(home, "BackButton") as Button
	_check(upgrade_grid != null and upgrade_grid.columns == 4 \
		and detail != null and detail.visible \
		and back != null and back.visible,
		"Power Up opens a four-column selection grid with fixed detail and Back controls")
	var all_meta_rows := meta != null and meta.upgrades.size() == 18
	if meta != null:
		for definition: MetaUpgradeDef in meta.upgrades:
			all_meta_rows = all_meta_rows and definition != null \
				and _find_named(home, "Upgrade_%s" % definition.id) != null \
				and _find_named(home, "Buy_%s" % definition.id) != null
	_check(all_meta_rows and _nodes_with_prefix(home, "Upgrade_").size() == 18,
		"Home renders one stable card and purchase control for all 18 upgrade lines")

	_click_nav(home, "PowerCatalogueTabButton")
	var powers := SurvivorsContent.run_powers()
	var all_power_rows := powers != null and powers.powers.size() == 27 \
		and powers.powers.size() <= RunPowerTable.MAX_POWER_COUNT
	var presented_core := 0
	var presented_blueprints := 0
	if powers != null:
		for definition: RunPowerDef in powers.powers:
			var card := _find_named(home, "Power_%s" % definition.id)
			all_power_rows = all_power_rows and definition != null and card != null
			if definition == null or card == null:
				continue
			if definition.pool == RunPowerDef.Pool.CORE \
					and GameState.is_run_power_unlocked(definition.id) \
					and _node_has_label(card, "UNLOCKED"):
				presented_core += 1
			elif definition.pool == RunPowerDef.Pool.BLUEPRINT \
					and not GameState.is_run_power_unlocked(definition.id) \
					and _node_has_label(card, "BLUEPRINT LOCKED"):
				presented_blueprints += 1
	_check(all_power_rows and _nodes_with_prefix(home, "Power_").size() == 27 \
		and presented_core == 14 and presented_blueprints == 13 \
		and GameState.get_unlocked_run_powers().size() == 14,
		"Power Catalogue presents all 27 powers with 14 Core unlocked")


func _test_records(home: StartupMenu) -> void:
	_click_nav(home, "RecordsTabButton")
	var records_ok := _node_has_label(home, "CAREER") \
		and _node_has_label(home, "HOME LUMBERYARD") \
		and _has_record_pair(home, "Roots completed", "42") \
		and _has_record_pair(home, "Home Cash earned", "987") \
		and _has_record_pair(home, "Bosses defeated", "3") \
		and _has_record_pair(home, "Attempts", "6") \
		and _has_record_pair(home, "Clears", "2") \
		and _has_record_pair(home, "Best clear", "17:25") \
		and _has_record_pair(home, "Longest endless", "2:03") \
		and _has_record_pair(home, "Highest level", "31") \
		and _has_record_pair(home, "Best session cash", "$456")
	_check(records_ok,
		"Records renders saved career totals and independent yard results")


func _test_suspended_lock(home: StartupMenu, frequency_cost: int) -> void:
	var banner := _find_named(home, "SuspendedLockBanner") as Control
	var start := _find_named(home, "StartRunButton") as Button
	var resume := _find_named(home, "ResumeAttemptButton") as Button
	var abandon := _find_named(home, "AbandonAttemptButton") as Button
	var new_profile := _find_named(home, "NewProfileButton") as Button
	_check(SaveSystem.has_suspended_attempt() \
		and GameState.are_permanent_controls_locked() \
		and banner != null and banner.visible \
		and start != null and not start.visible \
		and resume != null and resume.visible \
		and abandon != null and abandon.visible,
		"a real suspended production attempt exposes Resume/Abandon and the lock banner")
	_check(new_profile != null and new_profile.disabled,
		"suspension disables destructive profile replacement")

	_click_nav(home, "YardTabButton")
	var all_tiers_locked := _nodes_with_prefix(home, "FrequencyTier").size() == 4
	for node: Node in _nodes_with_prefix(home, "FrequencyTier"):
		all_tiers_locked = all_tiers_locked and node is Button \
			and (node as Button).disabled
	var tier_zero := _find_named(home, "FrequencyTier0Button") as Button
	if tier_zero != null:
		tier_zero.pressed.emit()
	_check(all_tiers_locked and GameState.get_selected_frequency_tier() == 1,
		"suspension disables every frequency control, including an otherwise legal tier")

	_click_nav(home, "UpgradesTabButton")
	var all_buys_locked := _nodes_with_prefix(home, "Buy_").size() == 18
	for node: Node in _nodes_with_prefix(home, "Buy_"):
		all_buys_locked = all_buys_locked and node is Button \
			and (node as Button).disabled
	var refund := _find_button_prefix(home, "Refund All")
	var axe_buy := _find_named(home, "Buy_axe_power") as Button
	var cash_before := GameState.get_home_cash()
	var ranks_before := GameState.get_meta_upgrade_ranks()
	if axe_buy != null:
		axe_buy.pressed.emit()
	if refund != null:
		refund.pressed.emit()
	_check(all_buys_locked and axe_buy != null and axe_buy.disabled \
		and refund != null and refund.disabled \
		and refund.text.contains("$%s" % _format_number(frequency_cost)) \
		and GameState.get_home_cash() == cash_before \
		and GameState.get_meta_upgrade_ranks() == ranks_before,
		"suspension disables all purchases and an otherwise available exact refund")


func _spawn_main() -> AxemanMain:
	var main := load("res://scenes/main.tscn").instantiate() as AxemanMain
	_active_main = main
	add_child(main)
	await _wait_frames(7)
	return main


func _dispose_main(main: AxemanMain) -> void:
	if main == null or not is_instance_valid(main):
		return
	if _active_main == main:
		_active_main = null
	main.queue_free()
	await _wait_frames(3)


func _home_from(main: AxemanMain) -> StartupMenu:
	return main.get_node("StartupOverlay/StartupMenu") as StartupMenu \
		if main != null else null


func _click_nav(home: StartupMenu, name: String) -> void:
	var button := _find_named(home, name) as Button
	if button != null:
		button.pressed.emit()


func _ledger_is_exact(id: StringName, expected: int) -> bool:
	var ledger := GameState.get_meta_upgrade_spend_ledger()
	var raw: Variant = ledger.get(String(id), [])
	return raw is Array and (raw as Array).size() == 1 \
		and int((raw as Array)[0]) == expected \
		and GameState.get_meta_upgrade_spend(id) == expected


func _find_named(root: Node, wanted: String) -> Node:
	if root == null:
		return null
	if root.name == wanted:
		return root
	for child: Node in root.get_children():
		var found := _find_named(child, wanted)
		if found != null:
			return found
	return null


func _nodes_with_prefix(root: Node, prefix: String) -> Array[Node]:
	var out: Array[Node] = []
	_collect_nodes_with_prefix(root, prefix, out)
	return out


func _collect_nodes_with_prefix(root: Node, prefix: String,
		out: Array[Node]) -> void:
	if root == null:
		return
	if String(root.name).begins_with(prefix):
		out.append(root)
	for child: Node in root.get_children():
		_collect_nodes_with_prefix(child, prefix, out)


func _find_button_prefix(root: Node, prefix: String) -> Button:
	if root == null:
		return null
	if root is Button and (root as Button).text.begins_with(prefix):
		return root as Button
	for child: Node in root.get_children():
		var found := _find_button_prefix(child, prefix)
		if found != null:
			return found
	return null


func _node_has_label(root: Node, exact_text: String) -> bool:
	if root == null:
		return false
	if root is Label and (root as Label).text == exact_text:
		return true
	for child: Node in root.get_children():
		if _node_has_label(child, exact_text):
			return true
	return false


func _has_record_pair(root: Node, label_text: String,
		value_text: String) -> bool:
	if root == null:
		return false
	if root is HBoxContainer:
		var direct_text := PackedStringArray()
		for child: Node in root.get_children():
			if child is Label:
				direct_text.append((child as Label).text)
		if label_text in direct_text and value_text in direct_text:
			return true
	for child: Node in root.get_children():
		if _has_record_pair(child, label_text, value_text):
			return true
	return false


func _label_text(root: Node, name: String) -> String:
	var label := _find_named(root, name) as Label
	return label.text if label != null else ""


func _format_number(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + grouped


func _wait_frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


func _capture_if_rendered(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	_check(error == OK, "rendered Home menu screenshot writes successfully")


func _on_watchdog() -> void:
	if _completed:
		return
	push_error("FAIL: production Home UI acceptance timed out")
	_cleanup()
	get_tree().quit(1)


func _cleanup() -> void:
	if _active_main != null and is_instance_valid(_active_main):
		_active_main.free()
	_active_main = null
	AudioDirector.end_session()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	_remove_save_files()
	SaveSystem.reset_save_path_after_tests()


func _remove_save_files() -> void:
	for suffix: String in ["", ".tmp", ".replacing"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_SAVE_PATH + suffix))


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("PASS: " + message)
	else:
		_failed += 1
		push_error("FAIL: " + message)
