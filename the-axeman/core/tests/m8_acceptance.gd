extends Node
## M8 acceptance: typed mastery reward contracts, bounded per-species progress,
## save-v3 migration/persistence, the manual-root once guard, and Slice 2's
## cumulative effect application plus Trees-tab presentation.

const _BACKUP_PATH := "user://the_axeman_save.m8_testbackup"
const _ChoppingMinigame := preload("res://scenes/3d_action/chopping_minigame.gd")

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== M8 SLICE 2 ACCEPTANCE — cumulative mastery effects + presentation ===")
	_stash_real_save()
	_test_live_mastery_contracts()
	_test_threshold_validator()
	_test_bounded_species_progress()
	_test_corrupt_progress_normalisation()
	_test_v1_v2_v3_migration()
	_test_save_reload()
	await _test_manual_root_once_guard()
	await _test_mastery_autosave()
	_test_cumulative_mastery_service()
	_test_market_mastery_and_order_exclusion()
	await _test_manual_xp_composition()
	await _test_split_reliability_and_cap()
	await _test_trees_mastery_presentation()
	_restore_real_save()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	print("=== M8 SLICE 2 RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL M8 SLICE 2 ACCEPTANCE CRITERIA PASS ===")
	get_tree().quit()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _test_live_mastery_contracts() -> void:
	var table := M7CContent.mastery()
	_check(table != null and table.thresholds.size() == 3,
		"the live mastery table has three authored reward thresholds")
	if table == null or table.thresholds.size() != 3:
		return
	_check([table.thresholds[0].required_progress,
		table.thresholds[1].required_progress,
		table.thresholds[2].required_progress] == [1, 5, 10],
		"the placeholder threshold ladder is ordered 1 / 5 / 10")
	var reward_contracts_ok := true
	for threshold: SpeciesMasteryThresholdDef in table.thresholds:
		var kinds: Dictionary = {}
		for reward: GameplayModifierDef in threshold.rewards:
			if reward != null:
				kinds[reward.kind] = true
				reward_contracts_ok = reward_contracts_ok \
					and reward.operation == GameplayModifierDef.Operation.ADD \
					and reward.magnitude > 0.0 \
					and reward.tuning_status.begins_with("PLACEHOLDER")
		reward_contracts_ok = reward_contracts_ok \
			and kinds.has(GameplayModifierDef.Kind.CASH_GAIN) \
			and kinds.has(GameplayModifierDef.Kind.MANUAL_XP) \
			and kinds.has(GameplayModifierDef.Kind.SPLIT_RELIABILITY) \
			and threshold.tuning_status.begins_with("PLACEHOLDER")
	_check(reward_contracts_ok,
		"every threshold carries labelled additive cash, XP and reliability placeholders")
	var final_threshold: SpeciesMasteryThresholdDef = table.thresholds.back()
	var definitions_ok := table.definitions.size() == SpeciesTable.count()
	for definition: SpeciesMasteryDef in table.definitions:
		definitions_ok = definitions_ok and definition != null \
			and definition.mastery_target == final_threshold.required_progress
		if definition != null:
			for requirement: CertificationRequirementDef in definition.certification_requirements:
				definitions_ok = definitions_ok and requirement != null \
					and requirement.kind == CertificationRequirementDef.Kind.MANUAL_LOGS \
					and requirement.required_count == definition.mastery_target
	_check(definitions_ok,
		"all live woods use the final threshold as mastery and only manual evidence ships")
	_check(M7CContent.validate_all().is_empty(),
		"all shipping typed content validates with the Slice 1 mastery contract")


func _test_threshold_validator() -> void:
	var table := SpeciesMasteryTable.new()
	var later := SpeciesMasteryThresholdDef.new()
	later.required_progress = 5
	var earlier := SpeciesMasteryThresholdDef.new()
	earlier.required_progress = 2
	table.thresholds = [later, earlier]
	var definition := SpeciesMasteryDef.new()
	definition.species_id = SpeciesTable.starting_species().id
	definition.mastery_target = 2
	table.definitions = [definition]
	var errors := M7CContent.validate_mastery(table)
	_check(_has_error(errors, "invalid threshold")
		and _has_error(errors, "missing reward kind"),
		"validation rejects unordered thresholds and incomplete reward bundles")


func _test_bounded_species_progress() -> void:
	GameState.reset_to_defaults()
	var aspen := SpeciesTable.at(0).id
	var pine := SpeciesTable.at(1).id
	var receipts: Array = []
	var receive := func(id: StringName, progress: int) -> void:
		receipts.append([id, progress])
	GameState.species_mastery_changed.connect(receive)
	# reset_to_defaults() ran before the connection, so only real writes appear.
	_check(GameState.get_species_mastery_progress(aspen) == 0
		and GameState.get_species_mastery_threshold_count(aspen) == 0
		and not GameState.is_species_mastered(aspen),
		"fresh mastery starts at zero with no reached threshold")
	_check(GameState.record_species_completion(aspen)
		and GameState.get_species_mastery_progress(aspen) == 1
		and GameState.get_species_mastery_threshold_count(aspen) == 1,
		"the first completed Aspen log reaches the first reward threshold")
	for _i in range(4):
		GameState.record_species_completion(aspen)
	_check(GameState.get_species_mastery_progress(aspen) == 5
		and GameState.get_species_mastery_threshold_count(aspen) == 2,
		"five completed Aspen logs reach exactly two reward thresholds")
	for _i in range(20):
		GameState.record_species_completion(aspen)
	_check(GameState.get_species_mastery_progress(aspen) == 10
		and GameState.get_species_mastery_threshold_count(aspen) == 3
		and GameState.is_species_mastered(aspen),
		"progress clamps at the final threshold and derives certification")
	var receipt_count := receipts.size()
	_check(not GameState.record_species_completion(aspen)
		and receipts.size() == receipt_count,
		"a mastered species refuses further progress without emitting a false change")
	_check(GameState.get_species_mastery_progress(pine) == 0,
		"mastery progress remains isolated per species")
	_check(not GameState.record_species_completion(&"invented_wood"),
		"an unknown species cannot create mastery progress")
	GameState.species_mastery_changed.disconnect(receive)


func _test_corrupt_progress_normalisation() -> void:
	var aspen := SpeciesTable.at(0).id
	var pine := SpeciesTable.at(1).id
	GameState.apply_save_dict({"species_mastery_progress": {
		String(aspen): 999,
		String(pine): -4,
		"invented_wood": 7,
	}})
	_check(GameState.get_species_mastery_progress(aspen) == 10,
		"oversized saved mastery clamps to the current authored target")
	_check(GameState.get_species_mastery_progress(pine) == 0,
		"negative saved mastery clamps to zero")
	var saved: Dictionary = GameState.to_save_dict().get("species_mastery_progress", {})
	_check(saved == {String(aspen): 10},
		"unknown and zero progress rows are dropped from the normalised save shape")
	GameState.apply_save_dict({"species_mastery_progress": ["malformed"]})
	_check(GameState.get_species_mastery_progress(aspen) == 0,
		"a malformed mastery field costs only mastery and degrades to empty")


func _test_v1_v2_v3_migration() -> void:
	var v2 := {"cash": 73}
	var migrated_v2 := SaveSystem._migrate(v2, 2)
	_check(migrated_v2.get("cash", 0) == 73
		and migrated_v2.get("species_mastery_progress", null) == {},
		"version 2 migrates forward with unrelated state intact and no invented mastery")
	_check(not v2.has("species_mastery_progress"),
		"migration remains pure and does not mutate its source dictionary")
	var migrated_v1 := SaveSystem._migrate({"skill_levels": {}}, 1)
	_check(migrated_v1.get("species_mastery_progress", null) == {},
		"version 1 migrates sequentially through the M7C and M8 shapes")
	var current := {"species_mastery_progress": {"quaking_aspen": 3}}
	_check(SaveSystem._migrate(current, SaveSystem.SAVE_VERSION) == current,
		"a version 3 progression dictionary is byte-shape idempotent")


func _test_save_reload() -> void:
	SaveSystem.delete_save()
	GameState.reset_to_defaults()
	var aspen := SpeciesTable.at(0).id
	GameState.record_species_completion(aspen)
	GameState.record_species_completion(aspen)
	_check(SaveSystem.save_game(), "a mastery-bearing version 3 save writes atomically")
	var cfg := ConfigFile.new()
	_check(cfg.load(SaveSystem.SAVE_PATH) == OK
		and int(cfg.get_value("meta", "version", -1)) == SaveSystem.SAVE_VERSION,
		"the saved file is stamped version 3")
	GameState.reset_to_defaults()
	_check(SaveSystem.load_game() == SaveSystem.LoadResult.OK
		and GameState.get_species_mastery_progress(aspen) == 2,
		"mastery progress survives save, reset and reload exactly")


func _test_manual_root_once_guard() -> void:
	GameState.reset_to_defaults()
	var aspen := SpeciesTable.at(0).id
	var mg: _ChoppingMinigame = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	mg.debug_forced_species = 0
	mg.debug_forced_mesh = 0
	mg.auto_sell = true
	mg.orbs_enabled = false
	add_child(mg)
	await get_tree().process_frame
	var base := SpeciesTable.at(0).xp_reward
	mg.debug_award_log_xp_event(&"manual", &"m8_manual_root", true, false, base)
	mg.debug_award_log_xp_event(&"manual", &"m8_manual_root", true, false, base)
	_check(GameState.get_species_mastery_progress(aspen) == 1,
		"one player-started completion root advances mastery exactly once")
	mg.debug_award_log_xp_event(&"manual", &"m8_bonus_root", true, true, base)
	mg.debug_award_log_xp_event(&"automation", &"m8_auto_root", true, false, base)
	mg.debug_award_log_xp_event(&"restored", &"m8_restore_root", true, false, base)
	mg.debug_award_log_xp_event(&"manual", &"m8_incomplete_root", false, false, base)
	_check(GameState.get_species_mastery_progress(aspen) == 1,
		"bonus, automation, restored and incomplete outcomes grant no mastery")
	mg.queue_free()
	await get_tree().process_frame


func _test_mastery_autosave() -> void:
	# Main owns the production autosave connections. Boot it over the test save,
	# then remove that file so the mastery write's deferred flush is observable.
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	SaveSystem.delete_save()
	var aspen := SpeciesTable.at(0).id
	var before := GameState.get_species_mastery_progress(aspen)
	GameState.record_species_completion(aspen)
	_check(not SaveSystem.has_save(),
		"mastery progression queues autosave instead of writing inside GameState")
	await get_tree().process_frame
	_check(SaveSystem.has_save(),
		"the queued mastery autosave flushes one complete save at frame end")
	var cfg := ConfigFile.new()
	var saved_progress := -1
	if cfg.load(SaveSystem.SAVE_PATH) == OK:
		var data: Variant = cfg.get_value("progression", "data", {})
		if data is Dictionary:
			var mastery: Variant = (data as Dictionary).get("species_mastery_progress", {})
			if mastery is Dictionary:
				saved_progress = int((mastery as Dictionary).get(String(aspen), -1))
	_check(saved_progress == before + 1,
		"the autosave contains the exact new mastery total")
	main.queue_free()
	await get_tree().process_frame


func _test_cumulative_mastery_service() -> void:
	var aspen := SpeciesTable.at(0).id
	var pine := SpeciesTable.at(1).id
	GameState.apply_save_dict({"species_mastery_progress": {
		String(aspen): 5,
		String(pine): 1,
	}})
	_check(is_equal_approx(
		SpeciesMastery.effect_for_species(aspen, GameplayModifierDef.Kind.CASH_GAIN), 0.003)
		and is_equal_approx(
			SpeciesMastery.effect_for_species(pine, GameplayModifierDef.Kind.CASH_GAIN), 0.001),
		"each species contributes every reward on every threshold it has reached")
	_check(is_equal_approx(
		SpeciesMastery.total_effect(GameplayModifierDef.Kind.CASH_GAIN), 0.004)
		and is_equal_approx(
			SpeciesMastery.total_effect(GameplayModifierDef.Kind.MANUAL_XP), 0.004)
		and is_equal_approx(
			SpeciesMastery.total_effect(GameplayModifierDef.Kind.SPLIT_RELIABILITY), 0.002),
		"same-stat cash, XP and reliability rewards add globally across species")
	var next := SpeciesMastery.next_threshold(aspen)
	_check(next != null and next.required_progress == 10,
		"the mastery service exposes the next unreached authored reward rung")


func _test_market_mastery_and_order_exclusion() -> void:
	GameState.apply_save_dict({"species_mastery_progress": {
		String(SpeciesTable.at(0).id): 10,
		String(SpeciesTable.at(1).id): 5,
	}})
	InventoryManager.apply_save_dict({})
	var item := SpeciesTable.at(0).yield_item
	var count := 1000
	var base_payout := Market.get_price(item) * count
	var mastery_cash := SpeciesMastery.total_effect(GameplayModifierDef.Kind.CASH_GAIN)
	var expected := int(round(float(base_payout) * (1.0 + mastery_cash)))
	InventoryManager.add_item(item, count)
	_check(Market.sell(item, count) == expected and GameState.get_cash() == expected,
		"ordinary firewood applies the summed mastery cash percentage once at the basket boundary")

	InventoryManager.add_item(item, 1)
	var cash_before_failed := GameState.get_cash()
	_check(Market.sell(item, 2) == 0
		and GameState.get_cash() == cash_before_failed
		and InventoryManager.get_count(item) == 1,
		"a mastery-bearing failed sale remains atomic in both cash and stock")
	InventoryManager.apply_save_dict({})

	var order := Orders.by_id(&"campfire_warmup")
	var before_order := GameState.get_cash()
	var ordinary_sales := 0
	_check(order != null and GameState.accept_order(order.id),
		"test setup: the introductory fixed-bonus order is accepted")
	if order != null:
		for _i in range(order.required_count):
			InventoryManager.add_item(item, 1)
			ordinary_sales += Orders.settle_piece(item)
		_check(GameState.get_cash() - before_order == ordinary_sales + order.cash_bonus,
			"mastery changes ordinary sale receipts but leaves the fixed order bonus exact")


func _test_manual_xp_composition() -> void:
	_set_every_species_mastered()
	var curve := load("res://data/level_curve.tres") as LevelCurve
	GameState.add_xp(curve.total_xp_for_level(4))
	_check(SkillTree.buy(&"quick_study") == 1,
		"test setup: Quick Study is owned for mastery composition")
	var mg: _ChoppingMinigame = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	mg.debug_forced_species = 0
	mg.debug_forced_mesh = 0
	mg.debug_force_proc = 1
	mg.auto_sell = true
	mg.orbs_enabled = false
	add_child(mg)
	await get_tree().process_frame

	var base: int = SpeciesTable.at(0).xp_reward
	var proc_multiplier := _manual_xp_multiplier(&"quick_study")
	var proc_total := int(round(float(base) * proc_multiplier))
	var mastery_xp := SpeciesMastery.total_effect(GameplayModifierDef.Kind.MANUAL_XP)
	var expected := int(round(float(proc_total) * (1.0 + mastery_xp)))
	var before := GameState.get_xp()
	var awarded: int = mg.debug_award_log_xp_event(
		&"manual", &"m8_composed_xp", true, false, base)
	_check(awarded == expected and GameState.get_xp() - before == expected,
		"manual-log mastery XP applies once after the existing Quick Study calculation")
	_check(mg.debug_last_quick_study_bonus() == proc_total - base
		and mg.debug_award_log_xp_event(
			&"manual", &"m8_composed_xp", true, false, base) == 0,
		"the proc receipt and completed-root recursion guard remain unchanged")

	var grain_multiplier := _manual_xp_multiplier(&"grain_read")
	var grain_proc_total := int(round(float(base) * grain_multiplier))
	var expected_grain := int(round(float(grain_proc_total) * (1.0 + mastery_xp)))
	before = GameState.get_xp()
	mg._award_grain_bonus(Vector3.ZERO)
	_check(mg.debug_last_grain_bonus() == expected_grain
		and GameState.get_xp() - before == expected_grain,
		"the manual grain-reward transaction also receives mastery after proc calculation")
	mg.queue_free()
	await get_tree().process_frame


func _test_split_reliability_and_cap() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var mg: _ChoppingMinigame = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	mg.debug_forced_species = 0
	mg.debug_forced_mesh = 0
	mg.auto_sell = false
	add_child(mg)
	await get_tree().process_frame
	var before := mg.debug_split_chance()
	_set_every_species_mastered()
	var reliability := SpeciesMastery.total_effect(GameplayModifierDef.Kind.SPLIT_RELIABILITY)
	var after := mg.debug_split_chance()
	_check(is_equal_approx(after, before + reliability),
		"all reached split-reliability rewards add before the existing split cap")
	mg.max_split_chance = before + reliability * 0.5
	_check(is_equal_approx(mg.debug_split_chance(), mg.max_split_chance),
		"the authored maximum split chance still caps cumulative mastery")
	mg.queue_free()
	await get_tree().process_frame


func _test_trees_mastery_presentation() -> void:
	GameState.reset_to_defaults()
	var aspen := SpeciesTable.at(0).id
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	var shop_button: Button = hud.get_node("QuickMenu/ShopButton")
	var tabs: TabContainer = hud.get_node("ShopPanel/Column/ShopTabs")
	var wood_list: VBoxContainer = hud.get_node(
		"ShopPanel/Column/ShopTabs/Trees/WoodScroll/WoodList")
	shop_button.pressed.emit()
	tabs.current_tab = 1
	var fresh_text := _text_under(wood_list)
	_check(fresh_text.contains("Mastery 0 / 10")
		and fresh_text.contains("Next reward at 1")
		and fresh_text.contains("+0.1% cash")
		and fresh_text.contains("+0.1% manual XP")
		and fresh_text.contains("+0.05 pts split"),
		"each owned Trees row shows progress and the complete next-threshold reward")
	GameState.record_species_completion(aspen)
	_check(_text_under(wood_list).contains("Mastery 1 / 10\nNext reward at 5"),
		"the open Trees tab repaints live from species_mastery_changed")
	for _i in range(9):
		GameState.record_species_completion(aspen)
	var mastered_text := _text_under(wood_list)
	var progress := _first_progress_bar(wood_list)
	_check(mastered_text.contains("Mastery 10 / 10  ·  Mastered")
		and progress != null
		and is_equal_approx(progress.value, 10.0)
		and is_equal_approx(progress.max_value, 10.0),
		"a completed species shows its mastered state and a full bounded progress bar")
	hud.queue_free()
	await get_tree().process_frame


func _set_every_species_mastered() -> void:
	var progress: Dictionary = {}
	var table := M7CContent.mastery()
	if table != null:
		for definition: SpeciesMasteryDef in table.definitions:
			if definition != null:
				progress[String(definition.species_id)] = definition.mastery_target
	GameState.apply_save_dict({"species_mastery_progress": progress})


func _manual_xp_multiplier(proc_id: StringName) -> float:
	var proc_def: ProcDef = M7CContent.procs().by_id(proc_id)
	if proc_def == null:
		return 1.0
	for modifier: GameplayModifierDef in proc_def.modifiers:
		if modifier != null \
				and modifier.kind == GameplayModifierDef.Kind.MANUAL_XP \
				and modifier.operation == GameplayModifierDef.Operation.MULTIPLY:
			return modifier.magnitude
	return 1.0


func _text_under(root: Node) -> String:
	var text := ""
	if root is Label:
		text += (root as Label).text + "\n"
	for child: Node in root.get_children():
		text += _text_under(child)
	return text


func _first_progress_bar(root: Node) -> ProgressBar:
	if root is ProgressBar:
		return root as ProgressBar
	for child: Node in root.get_children():
		var found := _first_progress_bar(child)
		if found != null:
			return found
	return null


func _has_error(errors: PackedStringArray, needle: String) -> bool:
	for error: String in errors:
		if error.contains(needle):
			return true
	return false


func _stash_real_save() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists(_BACKUP_PATH):
		dir.remove(_BACKUP_PATH)
	if dir.file_exists(SaveSystem.SAVE_PATH):
		dir.rename(SaveSystem.SAVE_PATH, _BACKUP_PATH)


func _restore_real_save() -> void:
	SaveSystem.delete_save()
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(_BACKUP_PATH):
		dir.rename(_BACKUP_PATH, SaveSystem.SAVE_PATH)
