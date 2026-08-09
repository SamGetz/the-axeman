extends Node
## M8 acceptance: typed mastery reward contracts, bounded per-species progress,
## save migration/persistence, the manual-root once guard, and Slice 2's
## cumulative effect application plus Trees-tab presentation. Slice 3 adds the
## Mechanical Splitter purchase/assignment foundation; Slice 4 adds one bounded,
## visible watched production cycle with receipt-safe inventory output. Slice 5
## adds a read-only Purchased shop tab derived from existing ownership tiers.
## Slice 6 expands the authored contract/profile ladder and adds dedicated,
## prewarmed watched-splitter reward presentation.

const _BACKUP_PATH := "user://the_axeman_save.m8_testbackup"
const _ChoppingMinigame := preload("res://scenes/3d_action/chopping_minigame.gd")
const _MechanicalSplitter := preload("res://core/mechanical_splitter.gd")

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== M8 SLICE 6 ACCEPTANCE — Certified Yard Expansion ===")
	_stash_real_save()
	_test_live_mastery_contracts()
	_test_threshold_validator()
	_test_bounded_species_progress()
	_test_corrupt_progress_normalisation()
	_test_v1_v2_v3_v4_v5_migration()
	_test_save_reload()
	await _test_manual_root_once_guard()
	await _test_mastery_autosave()
	_test_cumulative_mastery_service()
	_test_market_mastery_and_order_exclusion()
	await _test_manual_xp_composition()
	await _test_split_reliability_and_cap()
	await _test_trees_mastery_presentation()
	_test_splitter_catalogue_contracts()
	_test_later_profile_contract_mastery_gates()
	_test_splitter_unlocks_and_atomic_purchase()
	_test_splitter_save_reload()
	await _test_mastery_splitter_navigation()
	await _test_splitter_shop_presentation()
	await _test_purchased_shop_tab()
	await _test_splitter_runtime_contract_and_states()
	await _test_splitter_watched_cycle()
	await _test_splitter_species_ladder_samples()
	await _test_splitter_restore_safety()
	_test_splitter_upgrade_catalogue_and_pacing()
	await _test_splitter_upgrade_runtime()
	await _test_splitter_runtime_presentation()
	_restore_real_save()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	print("=== M8 SLICE 6 RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL M8 SLICE 6 ACCEPTANCE CRITERIA PASS ===")
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
	var definitions_ok := table.definitions.size() == SpeciesTable.count()
	var distinct_targets: Dictionary = {}
	for definition: SpeciesMasteryDef in table.definitions:
		definitions_ok = definitions_ok and definition != null \
			and definition.mastery_target >= 5 and definition.mastery_target <= 7 \
			and table.thresholds_for_species(definition.species_id).back().required_progress \
				== definition.mastery_target
		if definition != null:
			distinct_targets[definition.mastery_target] = true
			for requirement: CertificationRequirementDef in definition.certification_requirements:
				definitions_ok = definitions_ok and requirement != null \
					and requirement.kind == CertificationRequirementDef.Kind.MANUAL_LOGS \
					and requirement.use_mastery_target
	_check(definitions_ok and distinct_targets.size() == 3,
		"all live woods use per-species 5–7 log targets and only manual evidence ships")
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
		and GameState.get_species_mastery_threshold_count(aspen) == 3
		and GameState.is_species_mastered(aspen),
		"five completed Aspen logs reach its species-specific final reward threshold")
	for _i in range(20):
		GameState.record_species_completion(aspen)
	_check(GameState.get_species_mastery_progress(aspen) == 5
		and GameState.get_species_mastery_threshold_count(aspen) == 3
		and GameState.is_species_mastered(aspen),
		"progress clamps at Aspen's authored target and derives certification")
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
	_check(GameState.get_species_mastery_progress(aspen) == 5,
		"oversized saved mastery clamps to the current authored target")
	_check(GameState.get_species_mastery_progress(pine) == 0,
		"negative saved mastery clamps to zero")
	var saved: Dictionary = GameState.to_save_dict().get("species_mastery_progress", {})
	_check(saved == {String(aspen): 5},
		"unknown and zero progress rows are dropped from the normalised save shape")
	GameState.apply_save_dict({"species_mastery_progress": ["malformed"]})
	_check(GameState.get_species_mastery_progress(aspen) == 0,
		"a malformed mastery field costs only mastery and degrades to empty")


func _test_v1_v2_v3_v4_v5_migration() -> void:
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
	var migrated_v3 := SaveSystem._migrate({"species_mastery_progress": {}}, 3)
	_check(migrated_v3.get("splitter_assigned_species", "missing") == "",
		"version 3 migrates to an explicitly idle splitter without inventing assignment")
	var migrated_v4 := SaveSystem._migrate({"splitter_assigned_species": ""}, 4)
	_check(migrated_v4.get("commission_offers", null) == []
		and migrated_v4.get("active_commission", "missing") == ""
		and int(migrated_v4.get("completed_commissions", -1)) == 0,
		"version 4 migrates without inventing commission offers, progress or history")
	var current := {"species_mastery_progress": {"quaking_aspen": 3}}
	_check(SaveSystem._migrate(current, SaveSystem.SAVE_VERSION) == current,
		"a current-version progression dictionary is byte-shape idempotent")


func _test_save_reload() -> void:
	SaveSystem.delete_save()
	GameState.reset_to_defaults()
	var aspen := SpeciesTable.at(0).id
	GameState.record_species_completion(aspen)
	GameState.record_species_completion(aspen)
	_check(SaveSystem.save_game(), "a mastery-bearing current-version save writes atomically")
	var cfg := ConfigFile.new()
	_check(cfg.load(SaveSystem.SAVE_PATH) == OK
		and int(cfg.get_value("meta", "version", -1)) == SaveSystem.SAVE_VERSION,
		"the saved file is stamped with the current version")
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
	# then remove that file so the mastery write's quiet-window flush is observable.
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.start_new_game()
	await get_tree().process_frame
	SaveSystem.delete_save()
	var aspen := SpeciesTable.at(0).id
	var before := GameState.get_species_mastery_progress(aspen)
	GameState.record_species_completion(aspen)
	_check(not SaveSystem.has_save(),
		"mastery progression queues autosave instead of writing inside GameState")
	await get_tree().create_timer(main.autosave_quiet_seconds() + 0.05).timeout
	_check(SaveSystem.has_save(),
		"the queued mastery autosave flushes one complete save after the quiet window")
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
		SpeciesMastery.effect_for_species(aspen, GameplayModifierDef.Kind.CASH_GAIN), 0.006)
		and is_equal_approx(
			SpeciesMastery.effect_for_species(pine, GameplayModifierDef.Kind.CASH_GAIN), 0.001),
		"each species contributes every reward on every threshold it has reached")
	_check(is_equal_approx(
		SpeciesMastery.total_effect(GameplayModifierDef.Kind.CASH_GAIN), 0.007)
		and is_equal_approx(
			SpeciesMastery.total_effect(GameplayModifierDef.Kind.MANUAL_XP), 0.007)
		and is_equal_approx(
			SpeciesMastery.total_effect(GameplayModifierDef.Kind.SPLIT_RELIABILITY), 0.0035),
		"same-stat cash, XP and reliability rewards add globally across species")
	var next := SpeciesMastery.next_threshold(aspen)
	_check(next == null,
		"the mastery service reports no unreached rung after a species-specific target")


func _test_market_mastery_and_order_exclusion() -> void:
	GameState.apply_save_dict({"species_mastery_progress": {
		String(SpeciesTable.at(0).id): 5,
		String(SpeciesTable.at(1).id): 5,
	}})
	var jobs_curve := GameConfig.current().level_curve
	GameState.add_xp(jobs_curve.total_xp_for_level(Orders.JOBS_UNLOCK_LEVEL))
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
	var curve := GameConfig.current().level_curve
	# Quick Study now sits behind the complete ranked Mastery foundation. Drive
	# that authored path with earned points instead of relying on the pre-overhaul
	# level-4 shape that could buy the proc directly.
	GameState.add_xp(curve.total_xp_for_level(24))
	for id: StringName in [&"lessons_learned", &"studied_practice",
			&"keen_appraisal", &"balanced_growth", &"broad_experience",
			&"trusted_name"]:
		var definition := SkillTree.get_node_def(id)
		if definition == null:
			continue
		for _rank in range(definition.max_level):
			SkillTree.buy(id)
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
	var global_xp := SkillTree.total_modifier(GameplayModifierDef.Kind.GLOBAL_XP_GAIN)
	var expected_before_global := int(round(float(proc_total) * (1.0 + mastery_xp)))
	var expected := int(round(float(expected_before_global) \
		* GameConfig.current().xp_pacing.global_xp_multiplier * (1.0 + global_xp)))
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
	var expected_grain_before_global := int(round(
		float(grain_proc_total) * (1.0 + mastery_xp)))
	var expected_grain := int(round(float(expected_grain_before_global) \
		* GameConfig.current().xp_pacing.global_xp_multiplier * (1.0 + global_xp)))
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
	var trees_button: Button = hud.get_node("QuickMenu/TreesButton")
	var wood_list: VBoxContainer = hud.get_node(
		"TreesPanel/Column/WoodScroll/WoodList")
	var target := M7CContent.mastery().by_species_id(aspen).mastery_target
	var thresholds := M7CContent.mastery().thresholds_for_species(aspen)
	trees_button.pressed.emit()
	var fresh_text := _text_under(wood_list)
	_check(fresh_text.contains("Mastery 0 / %d" % target)
		and fresh_text.contains("Next reward at 1")
		and fresh_text.contains("+0.1% cash")
		and fresh_text.contains("+0.1% manual XP")
		and fresh_text.contains("+0.05 pts split"),
		"each owned Tree Catalog row shows progress and the complete next-threshold reward")
	GameState.record_species_completion(aspen)
	_check(_text_under(wood_list).contains("Mastery 1 / %d\nNext reward at %d" % [
		target, thresholds[1].required_progress]),
		"the open Tree Catalog repaints live from species_mastery_changed")
	for _i in range(target - 1):
		GameState.record_species_completion(aspen)
	var mastered_text := _text_under(wood_list)
	var progress := _first_progress_bar(wood_list)
	_check(mastered_text.contains("Mastery %d / %d  ·  Mastered" % [target, target])
		and progress != null
		and is_equal_approx(progress.value, float(target))
		and is_equal_approx(progress.max_value, float(target)),
		"a completed species shows its mastered state and a full bounded progress bar")
	hud.queue_free()
	await get_tree().process_frame


func _test_splitter_catalogue_contracts() -> void:
	var machine: UpgradeDef = _MechanicalSplitter.machine_definition()
	var profiles: Array[UpgradeDef] = _MechanicalSplitter.profile_definitions()
	_check(machine != null and profiles.size() == SpeciesTable.count(),
		"the live catalogue has one Mechanical Splitter and one profile for all 25 species")
	var early_species: Array[StringName] = []
	var approved_tuning_ok := machine != null \
		and machine.required_mastered_species_count == 3 \
		and machine.base_cost == 1000 \
		and machine.tuning_status.begins_with("APPROVED")
	for index in range(mini(3, profiles.size())):
		var profile: UpgradeDef = profiles[index]
		early_species.append(profile.automation_species_id)
		approved_tuning_ok = approved_tuning_ok \
			and profile.base_cost == 250 \
			and profile.tuning_status.begins_with("APPROVED") \
			and profile.effect == UpgradeDef.Effect.NONE
	_check(early_species == [SpeciesTable.at(0).id, SpeciesTable.at(1).id,
		SpeciesTable.at(2).id],
		"the first three profiles preserve their approved Aspen, Pine and Norway order")
	_check(approved_tuning_ok,
		"machine certification gate and profile prices carry Sam's approved tuning")
	var later_profiles_ok := profiles.size() == SpeciesTable.count()
	for index in range(3, profiles.size()):
		var profile: UpgradeDef = profiles[index]
		var species := SpeciesTable.at(index)
		var expected_cost := maxi(250,
			int(ceil(float(species.unlock_cost) * 0.20 / 50.0)) * 50)
		later_profiles_ok = later_profiles_ok \
			and profile.id == StringName("splitter_profile_%s" % species.id) \
			and profile.display_name == "Splitter Profile · %s" % species.display_name \
			and profile.automation_species_id == species.id \
			and profile.required_mastery_species_id == species.id \
			and profile.required_upgrade_id == machine.id \
			and profile.unlock_order_id == StringName("%s_delivery" % species.id) \
			and profile.base_cost == expected_cost \
			and profile.tuning_status == "PLACEHOLDER — post-M8 measured tuning required"
	_check(later_profiles_ok,
		"Balsam Fir through Lignum Vitae each have their own contract-gated labelled profile")
	_check(_MechanicalSplitter.validate_live_catalogue().is_empty()
			and Orders.validate_live_catalogue().is_empty(),
		"the shipping contract/profile catalogues pass semantic and cross-table validation")

	var malformed := UpgradeDef.new()
	malformed.id = &"bad_profile"
	malformed.automation_role = UpgradeDef.AutomationRole.CUTTING_PROFILE
	malformed.automation_species_id = &"invented_wood"
	var uncertified := UpgradeDef.new()
	uncertified.id = &"uncertified_profile"
	uncertified.automation_role = UpgradeDef.AutomationRole.CUTTING_PROFILE
	uncertified.automation_species_id = SpeciesTable.at(0).id
	var malformed_catalogue: Array[UpgradeDef] = [malformed, uncertified]
	var errors: PackedStringArray = _MechanicalSplitter.validate_catalogue(malformed_catalogue)
	_check(_has_error(errors, "purchase is missing")
		and _has_error(errors, "unknown species")
		and _has_error(errors, "own certification"),
		"validation rejects an orphaned profile for an unknown, uncertified species")


func _test_later_profile_contract_mastery_gates() -> void:
	SaveSystem.delete_save()
	GameState.reset_to_defaults()
	var machine := _MechanicalSplitter.machine_definition()
	var profile: UpgradeDef = _MechanicalSplitter.profile_definitions()[3]
	var species := SpeciesTable.by_id(profile.automation_species_id)
	var target: int = M7CContent.mastery().by_species_id(species.id).mastery_target
	var machine_tiers := {String(machine.id): GameState.DEFAULT_BUILDING_TIER + 1}
	var mastery := {String(species.id): target}

	GameState.apply_save_dict({
		"building_tiers": machine_tiers,
		"species_mastery_progress": mastery,
	})
	_check(not Shop.is_visible(profile.id),
		"a later profile stays hidden when only its matching contract gate is missing")
	GameState.apply_save_dict({
		"building_tiers": machine_tiers,
		"completed_orders": [String(profile.unlock_order_id)],
	})
	_check(not Shop.is_visible(profile.id),
		"a later profile stays hidden when only its species certification is missing")
	GameState.apply_save_dict({
		"building_tiers": {},
		"species_mastery_progress": mastery,
		"completed_orders": [String(profile.unlock_order_id)],
	})
	_check(not Shop.is_visible(profile.id),
		"a later profile stays hidden when only the Mechanical Splitter is missing")
	GameState.apply_save_dict({
		"building_tiers": machine_tiers,
		"species_mastery_progress": mastery,
		"completed_orders": [String(profile.unlock_order_id)],
	})
	_check(Shop.is_visible(profile.id) and Shop.is_unlocked(profile.id),
		"contract, own certification and machine ownership reveal the later profile together")
	GameState.add_cash(profile.base_cost)
	_check(Shop.buy(profile.id) == 1
			and _MechanicalSplitter.can_accept_species(species.id)
			and GameState.assign_splitter_species(species.id),
		"the revealed later profile purchases atomically and admits only its own species")
	_check(SaveSystem.save_game(), "the later profile and assignment write through the current save version")
	GameState.reset_to_defaults()
	_check(SaveSystem.load_game() == SaveSystem.LoadResult.OK
			and Shop.get_level(profile.id) == 1
			and GameState.get_splitter_assigned_species() == species.id,
		"the later contract, certification, profile and assignment restore together")


func _test_splitter_unlocks_and_atomic_purchase() -> void:
	GameState.reset_to_defaults()
	var machine: UpgradeDef = _MechanicalSplitter.machine_definition()
	var profiles: Array[UpgradeDef] = _MechanicalSplitter.profile_definitions()
	if machine == null or profiles.is_empty():
		_check(false, "splitter purchase setup has live machine/profile definitions")
		return
	_check(not _MechanicalSplitter.is_installed()
		and not _MechanicalSplitter.can_accept_species(SpeciesTable.at(0).id),
		"a fresh yard has no splitter installation or automated species admission")

	var owned_prerequisites := {
		String(GameState.UPGRADE_BALANCED_AXE): 2,
		String(GameState.UPGRADE_REINFORCED_BLOCK): 2,
		String(GameState.UPGRADE_SUPPLIER_LEDGER): 2,
		String(GameState.UPGRADE_HANDCART): 2,
		String(GameState.UPGRADE_COFFEE_THERMOS): 2,
	}
	GameState.apply_save_dict({"building_tiers": owned_prerequisites})
	_set_mastery_for_species(2)
	_check(not Shop.is_unlocked(machine.id),
		"the machine remains locked below its labelled certification-count gate")
	_set_mastery_for_species(3)
	_check(Shop.is_unlocked(machine.id) and Shop.is_visible(machine.id)
		and not Shop.is_unlocked(profiles[0].id)
		and not Shop.is_visible(profiles[0].id),
		"three certifications reveal only the machine while locked profiles stay hidden")
	var cash_before := GameState.get_cash()
	_check(Shop.buy(machine.id) == -1
		and GameState.get_cash() == cash_before
		and not _MechanicalSplitter.is_installed(),
		"an unaffordable machine purchase is atomic")
	GameState.add_cash(machine.base_cost)
	_check(Shop.buy(machine.id) == 1 and _MechanicalSplitter.is_installed(),
		"the certified cash purchase installs exactly one Mechanical Splitter")
	var profile := profiles[0]
	cash_before = GameState.get_cash()
	_check(Shop.buy(profile.id) == -1
		and GameState.get_cash() == cash_before
		and not _MechanicalSplitter.has_installed_profile(profile.automation_species_id),
		"an unaffordable profile purchase spends nothing and installs nothing")
	GameState.add_cash(profile.base_cost)
	_check(Shop.buy(profile.id) == 1
		and _MechanicalSplitter.can_accept_species(profile.automation_species_id)
		and not _MechanicalSplitter.can_accept_species(profiles[1].automation_species_id),
		"one paid certified profile admits only its own species")
	var assignment_receipts: Array[StringName] = []
	var receive_assignment := func(id: StringName) -> void:
		assignment_receipts.append(id)
	GameState.splitter_assignment_changed.connect(receive_assignment)
	_check(GameState.assign_splitter_species(profile.automation_species_id)
		and GameState.get_splitter_assigned_species() == profile.automation_species_id
		and assignment_receipts == [profile.automation_species_id],
		"the tree-side command records one eligible splitter assignment")
	_check(not GameState.assign_splitter_species(profiles[1].automation_species_id)
		and GameState.get_splitter_assigned_species() == profile.automation_species_id
		and assignment_receipts.size() == 1,
		"a species without an installed profile cannot replace the current assignment")
	GameState.splitter_assignment_changed.disconnect(receive_assignment)


func _test_splitter_save_reload() -> void:
	SaveSystem.delete_save()
	GameState.reset_to_defaults()
	var machine: UpgradeDef = _MechanicalSplitter.machine_definition()
	var profile: UpgradeDef = _MechanicalSplitter.profile_definitions()[0]
	var tiers := {
		String(machine.id): GameState.DEFAULT_BUILDING_TIER + 1,
		String(profile.id): GameState.DEFAULT_BUILDING_TIER + 1,
	}
	var progress: Dictionary = {}
	progress[String(profile.automation_species_id)] = \
		M7CContent.mastery().by_species_id(profile.automation_species_id).mastery_target
	GameState.apply_save_dict({
		"building_tiers": tiers,
		"species_mastery_progress": progress,
		"splitter_assigned_species": String(profile.automation_species_id),
	})
	_check(SaveSystem.save_game(),
		"installed splitter/profile ownership writes through the existing atomic save")
	GameState.reset_to_defaults()
	_check(not _MechanicalSplitter.is_installed(),
		"reset clears installed automation without changing immutable catalogue data")
	_check(SaveSystem.load_game() == SaveSystem.LoadResult.OK
		and _MechanicalSplitter.is_installed()
		and _MechanicalSplitter.can_accept_species(profile.automation_species_id)
		and GameState.get_splitter_assigned_species() == profile.automation_species_id,
		"machine, profile, certification and assignment survive reset and reload together")
	GameState.reset_to_defaults()
	GameState.apply_save_dict({
		"species_mastery_progress": progress,
		"splitter_assigned_species": String(profile.automation_species_id),
	})
	_check(GameState.get_splitter_assigned_species() == &"",
		"a crafted assignment without installed machine/profile ownership is dropped")
	var migrated := SaveSystem._migrate({"building_tiers": {}}, 2)
	_check(not (migrated.get("building_tiers", {}) as Dictionary).has(String(machine.id)),
		"an older save migration never invents splitter ownership")


func _test_mastery_splitter_navigation() -> void:
	GameState.reset_to_defaults()
	GameState.apply_save_dict({"building_tiers": {
		String(GameState.UPGRADE_BALANCED_AXE): 2,
		String(GameState.UPGRADE_REINFORCED_BLOCK): 2,
		String(GameState.UPGRADE_SUPPLIER_LEDGER): 2,
		String(GameState.UPGRADE_HANDCART): 2,
		String(GameState.UPGRADE_COFFEE_THERMOS): 2,
	}})
	_set_mastery_for_species(3)
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	var trees_button: Button = hud.get_node("QuickMenu/TreesButton")
	var wood_list: VBoxContainer = hud.get_node("TreesPanel/Column/WoodScroll/WoodList")
	var tabs: TabContainer = hud.get_node("ShopPanel/Column/ShopTabs")
	var shop_panel: Control = hud.get_node("ShopPanel")
	trees_button.pressed.emit()
	var machine_route := _find_button_with_text(wood_list, "Open Splitter shop")
	var mastery_copy := _control_text_under(wood_list)
	_check(machine_route == null and mastery_copy.contains("Splitter certifications 3 / 3"),
		"mastery advertises its machine reward without exposing locked splitter controls")
	hud.get_node("QuickMenu/ShopButton").pressed.emit()
	_check(shop_panel.visible and not tabs.is_tab_hidden(1),
		"earning the machine reward reveals the Mechanical Splitter shop tab")
	hud.get_node("ShopPanel/Column/CloseShopButton").pressed.emit()

	var machine := _MechanicalSplitter.machine_definition()
	EventBus.building_upgraded.emit(machine.id, GameState.DEFAULT_BUILDING_TIER + 1)
	trees_button.pressed.emit()
	var profile_route := _find_button_with_text(wood_list, "Buy profile in Shop")
	if profile_route != null:
		profile_route.pressed.emit()
	_check(profile_route != null and not profile_route.disabled
		and shop_panel.visible and tabs.current_tab == 1,
		"an installed machine leaves a mastered tree's required profile purchase actionable")
	hud.queue_free()
	await get_tree().process_frame


func _test_splitter_shop_presentation() -> void:
	GameState.reset_to_defaults()
	var prerequisites := {
		String(GameState.UPGRADE_BALANCED_AXE): 2,
		String(GameState.UPGRADE_REINFORCED_BLOCK): 2,
		String(GameState.UPGRADE_SUPPLIER_LEDGER): 2,
		String(GameState.UPGRADE_HANDCART): 2,
		String(GameState.UPGRADE_COFFEE_THERMOS): 2,
	}
	GameState.apply_save_dict({"building_tiers": prerequisites})
	_set_mastery_for_species(2)
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	var shop_button: Button = hud.get_node("QuickMenu/ShopButton")
	var tabs: TabContainer = hud.get_node("ShopPanel/Column/ShopTabs")
	var shop_list: VBoxContainer = hud.get_node(
		"ShopPanel/Column/ShopTabs/Splitter/Scroll/List")
	shop_button.pressed.emit()
	_check(tabs.is_tab_hidden(1) and shop_list.get_child_count() == 0,
		"below three certifications the entire locked splitter shelf stays hidden")
	var locked_text := _control_text_under(shop_list)
	_check(not locked_text.contains("Mechanical Splitter"),
		"the hidden splitter shelf leaks no disabled machine row")
	var third := SpeciesTable.at(2).id
	var target: int = M7CContent.mastery().by_species_id(third).mastery_target
	for _i in range(target):
		GameState.record_species_completion(third)
	tabs.current_tab = 1
	var unlocked_text := _control_text_under(shop_list)
	_check(unlocked_text.contains("1K")
		and not unlocked_text.contains("Splitter Profile · Quaking Aspen")
		and not tabs.is_tab_hidden(1),
		"the earned splitter tab reveals the machine but keeps unearned profiles hidden")
	var machine := _MechanicalSplitter.machine_definition()
	EventBus.building_upgraded.emit(machine.id, GameState.DEFAULT_BUILDING_TIER + 1)
	unlocked_text = _control_text_under(shop_list)
	_check(unlocked_text.contains("Splitter Profile · Quaking Aspen")
		and unlocked_text.contains("Splitter Speed"),
		"buying the machine reveals certified profiles and the upgrade chain advertises its next reward")
	var profile := _MechanicalSplitter.profile_for_species(SpeciesTable.at(0).id)
	EventBus.building_upgraded.emit(profile.id, GameState.DEFAULT_BUILDING_TIER + 1)
	var trees_button: Button = hud.get_node("QuickMenu/TreesButton")
	var wood_list: VBoxContainer = hud.get_node("TreesPanel/Column/WoodScroll/WoodList")
	trees_button.pressed.emit()
	var assign := _find_button_with_text(wood_list, "Assign to splitter")
	if assign != null:
		assign.pressed.emit()
	var tree_text := _control_text_under(wood_list)
	_check(assign != null
		and GameState.get_splitter_assigned_species() == SpeciesTable.at(0).id
		and tree_text.contains("Current assignment")
		and tree_text.contains("Assigned"),
		"the standalone Tree Catalog owns assignment and repaints the chosen profile")
	hud.queue_free()
	await get_tree().process_frame


## Six Slice 5 checks pin the approved movement contract without introducing a
## second ownership authority: before purchase, after one-time purchase, through
## partial/maxed tiered ranks, and after a real save restoration.
func _test_purchased_shop_tab() -> void:
	SaveSystem.delete_save()
	GameState.reset_to_defaults()
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	var tabs: TabContainer = hud.get_node("ShopPanel/Column/ShopTabs")
	var items: VBoxContainer = hud.get_node(
		"ShopPanel/Column/ShopTabs/Items/ShopScroll/ShopList")
	var splitter: VBoxContainer = hud.get_node(
		"ShopPanel/Column/ShopTabs/Splitter/Scroll/List")
	var purchased: VBoxContainer = hud.get_node(
		"ShopPanel/Column/ShopTabs/Purchased/Scroll/List")
	hud.get_node("QuickMenu/ShopButton").pressed.emit()
	_check(tabs.get_tab_count() == 3
		and tabs.get_tab_title(0) == "Items"
		and tabs.get_tab_title(1) == "Mechanical Splitter"
		and tabs.get_tab_title(2) == "Purchased"
		and _control_text_under(items).contains("Balanced Axe")
		and purchased.get_child_count() == 0,
		"fresh purchases stay in functional tabs before the empty Purchased tab")

	EventBus.building_upgraded.emit(GameState.UPGRADE_BALANCED_AXE,
		GameState.DEFAULT_BUILDING_TIER + 1)
	_check(not _control_text_under(items).contains("Balanced Axe")
		and _control_text_under(purchased).contains("Balanced Axe")
		and _control_text_under(purchased).contains("Owned")
		and _button_count(purchased) == 0,
		"a completed Items one-time purchase moves to a read-only Owned row")

	var prerequisites := {
		String(GameState.UPGRADE_BALANCED_AXE): GameState.DEFAULT_BUILDING_TIER + 1,
		String(GameState.UPGRADE_REINFORCED_BLOCK): GameState.DEFAULT_BUILDING_TIER + 1,
		String(GameState.UPGRADE_SUPPLIER_LEDGER): GameState.DEFAULT_BUILDING_TIER + 1,
		String(GameState.UPGRADE_HANDCART): GameState.DEFAULT_BUILDING_TIER + 1,
		String(GameState.UPGRADE_COFFEE_THERMOS): GameState.DEFAULT_BUILDING_TIER + 1,
	}
	GameState.apply_save_dict({"building_tiers": prerequisites})
	_set_mastery_for_species(3)
	var machine := _MechanicalSplitter.machine_definition()
	var profile := _MechanicalSplitter.profile_definitions()[0]
	EventBus.building_upgraded.emit(machine.id, GameState.DEFAULT_BUILDING_TIER + 1)
	EventBus.building_upgraded.emit(profile.id, GameState.DEFAULT_BUILDING_TIER + 1)
	var splitter_text := _control_text_under(splitter)
	var purchased_text := _control_text_under(purchased)
	_check(splitter.get_node_or_null(String(machine.id)) == null
		and splitter.get_node_or_null(String(profile.id)) == null
		and splitter_text.contains("Splitter Profile · Eastern White Pine")
		and purchased.get_node_or_null(String(machine.id)) != null
		and purchased.get_node_or_null(String(profile.id)) != null
		and _button_count(purchased) == 0,
		"completed machine/profile purchases move while later splitter rows remain functional")

	var speed := _MechanicalSplitter.upgrade_definition(
		UpgradeDef.Effect.AUTOMATION_SPEED)
	EventBus.building_upgraded.emit(speed.id, GameState.DEFAULT_BUILDING_TIER + 1)
	splitter_text = _control_text_under(splitter)
	purchased_text = _control_text_under(purchased)
	_check(splitter_text.contains("Splitter Speed  (rank 1)")
		and splitter_text.contains(str(speed.cost_for_level(1)))
		and purchased.get_node_or_null(String(speed.id)) == null,
		"a partially purchased tiered upgrade stays functional while another rank remains")

	EventBus.building_upgraded.emit(speed.id,
		GameState.DEFAULT_BUILDING_TIER + speed.max_level)
	splitter_text = _control_text_under(splitter)
	purchased_text = _control_text_under(purchased)
	_check(splitter.get_node_or_null(String(speed.id)) == null
		and purchased.get_node_or_null(String(speed.id)) != null
		and purchased_text.contains("Maxed · rank %d/%d" % [speed.max_level,
			speed.max_level])
		and _button_count(purchased) == 0,
		"a fully purchased tiered upgrade moves to a read-only max-rank row")

	var saved_without_history := SaveSystem.save_game() \
		and not GameState.to_save_dict().has("purchase_history")
	GameState.reset_to_defaults()
	var restored := SaveSystem.load_game() == SaveSystem.LoadResult.OK
	await get_tree().process_frame
	splitter_text = _control_text_under(splitter)
	purchased_text = _control_text_under(purchased)
	_check(saved_without_history and restored
		and purchased_text.contains(machine.display_name)
		and purchased_text.contains(profile.display_name)
		and purchased_text.contains("Maxed · rank %d/%d" % [speed.max_level,
			speed.max_level])
		and splitter.get_node_or_null(String(speed.id)) == null,
		"save restoration re-derives identical Purchased placement from building tiers")
	hud.queue_free()
	await get_tree().process_frame


func _test_splitter_runtime_contract_and_states() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var config := GameConfig.current().mechanical_splitter
	_check(config != null and config.queue_capacity == 1
		and config.base_logs_per_split == 5
		and config.maximum_logs_per_split == 12
		and is_equal_approx(config.processing_duration_seconds, 5.0)
		and config.output_amount == 1
		and is_equal_approx(config.base_xp_rate, 0.20)
		and is_equal_approx(config.minimum_duration_multiplier, 0.50)
		and config.tuning_status.begins_with("APPROVED")
		and config.validate().is_empty(),
		"cycle data carries Sam's complete approved watched-runtime tuning band")
	var all_titles := PackedStringArray()
	for state: MechanicalSplitterRuntime.State in MechanicalSplitterRuntime.State.values():
		all_titles.append(MechanicalSplitterRuntime.state_title(state))
	_check(all_titles == PackedStringArray(["LOCKED", "UNASSIGNED", "MISSING PROFILE",
		"READY", "PROCESSING", "OUTPUT BLOCKED", "EARTH EXHAUSTED"]),
		"all seven watched machine states have explicit legible player-facing titles")

	var runtime := MechanicalSplitterRuntime.new()
	add_child(runtime)
	await get_tree().process_frame
	_check(runtime.current_state() == MechanicalSplitterRuntime.State.LOCKED,
		"an unpurchased splitter runtime is locked")
	var machine := _MechanicalSplitter.machine_definition()
	var profile := _MechanicalSplitter.profile_definitions()[0]
	GameState.apply_save_dict({"building_tiers": {
		String(machine.id): GameState.DEFAULT_BUILDING_TIER + 1,
	}})
	_check(runtime.current_state() == MechanicalSplitterRuntime.State.UNASSIGNED,
		"a purchased splitter without a Tree Catalog route is unassigned")
	# Deliberately inject the crafted/stale combination GameState normally rejects,
	# proving the runtime diagnoses it rather than silently accepting the species.
	GameState._splitter_assigned_species = profile.automation_species_id
	_check(runtime.current_state() == MechanicalSplitterRuntime.State.MISSING_PROFILE,
		"a stale assignment without its installed profile is diagnosed as missing profile")
	GameState.apply_save_dict(_splitter_runtime_save_shape(profile))
	var started_receipts: Array[StringName] = []
	var cancelled_receipts: Array[StringName] = []
	runtime.cycle_settlement_started.connect(func(receipt_id: StringName,
			_species_id: StringName) -> void: started_receipts.append(receipt_id))
	runtime.cycle_settlement_cancelled.connect(func(receipt_id: StringName) -> void:
		cancelled_receipts.append(receipt_id))
	runtime._pending_output = {
		"receipt_id": &"m8_blocked_receipt",
		"species_id": profile.automation_species_id,
		"item_id": &"invented_firewood",
		"amount": 1,
		"logs": 5,
		"inventory_deposited": false,
	}
	var cash_before := GameState.get_cash()
	_check(not runtime.retry_blocked_output()
			and started_receipts == [&"m8_blocked_receipt"]
			and cancelled_receipts == [&"m8_blocked_receipt"]
			and GameState.get_cash() == cash_before,
		"a failed handoff starts then cancels the same cosmetic receipt without progression")
	_check(not runtime.retry_blocked_output()
			and started_receipts == [&"m8_blocked_receipt", &"m8_blocked_receipt"]
			and cancelled_receipts == [&"m8_blocked_receipt", &"m8_blocked_receipt"],
		"retry creates one fresh pending presentation for the immutable blocked output")
	runtime.queue_free()
	await get_tree().process_frame


func _test_splitter_watched_cycle() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var profile := _MechanicalSplitter.profile_definitions()[0]
	GameState.apply_save_dict(_splitter_runtime_save_shape(profile))
	var jobs_curve := GameConfig.current().level_curve
	GameState.add_xp(jobs_curve.total_xp_for_level(Orders.JOBS_UNLOCK_LEVEL))
	var species := SpeciesTable.by_id(profile.automation_species_id)
	var runtime := MechanicalSplitterRuntime.new()
	add_child(runtime)
	await get_tree().process_frame
	var config := runtime.config
	var before_item := InventoryManager.get_count(species.yield_item)
	var before_cash := GameState.get_cash()
	var before_xp := GameState.get_xp()
	var before_mastery := GameState.get_species_mastery_progress(species.id)
	var before_lifetime := GameState.get_lifetime_wood_chopped()
	var expected_logs := runtime.effective_logs_per_split()
	var expected_amount := runtime.effective_output_amount()
	var expected_cash := Market.get_price(species.yield_item) * expected_amount
	var expected_xp := int(round(float(species.xp_reward * expected_logs)
		* config.base_xp_rate * GameConfig.current().xp_pacing.global_xp_multiplier))
	var order := Orders.by_id(&"campfire_warmup")
	var order_started := order != null and GameState.accept_order(order.id)
	var before_order_progress := GameState.get_active_order_progress()
	var receipts: Array[Dictionary] = []
	var settlement_events: Array[String] = []
	runtime.cycle_settlement_started.connect(func(receipt_id: StringName,
			_species_id: StringName) -> void:
		settlement_events.append("started:%s" % receipt_id))
	runtime.cycle_settlement_cancelled.connect(func(receipt_id: StringName) -> void:
		settlement_events.append("cancelled:%s" % receipt_id))
	GameState.cash_changed.connect(func(_cash: int) -> void:
		settlement_events.append("cash"), CONNECT_ONE_SHOT)
	runtime.cycle_completed.connect(func(species_id: StringName, item_id: StringName,
			amount: int, receipt_id: StringName) -> void:
		receipts.append({"species": species_id, "item": item_id,
			"amount": amount, "receipt": receipt_id})
		settlement_events.append("completed:%s" % receipt_id))
	_check(runtime.current_state() == MechanicalSplitterRuntime.State.READY
		and runtime.state_detail().contains(species.display_name),
		"the persisted Tree Catalog assignment is the ready runtime's sole route")
	_check(runtime.try_queue_assigned_input() and not runtime.try_queue_assigned_input()
		and runtime.queued_count() == config.queue_capacity
		and runtime.current_state() == MechanicalSplitterRuntime.State.PROCESSING,
		"one assigned log fills the bounded slot and a second admission is refused")
	runtime._process(config.processing_duration_seconds)
	_check(InventoryManager.get_count(species.yield_item) == before_item
		and is_zero_approx(runtime.progress()),
		"processing time does not advance while the yard runtime is inactive")
	runtime.set_yard_active(true)
	runtime._process(config.processing_duration_seconds * 0.5)
	_check(runtime.current_state() == MechanicalSplitterRuntime.State.PROCESSING
		and runtime.progress() > 0.0 and runtime.progress() < 1.0
		and InventoryManager.get_count(species.yield_item) == before_item,
		"a partial watched cycle shows progress without early output")
	runtime._process(config.processing_duration_seconds)
	_check(InventoryManager.get_count(species.yield_item) == before_item
		and receipts.size() == 1
		and receipts[0].item == species.yield_item
		and receipts[0].species == species.id
		and receipts[0].amount == expected_amount
		and receipts[0].receipt != &""
		and runtime.last_cash_earned() == expected_cash
		and runtime.last_xp_earned() == expected_xp
		and GameState.get_cash() == before_cash + expected_cash
		and GameState.get_xp() == before_xp + expected_xp,
		"completion sells SpeciesDef.yield_item once and pays base cash plus 20% species XP")
	_check(settlement_events == ["started:%s" % receipts[0].receipt, "cash",
			"completed:%s" % receipts[0].receipt],
		"presentation starts before authoritative cash and completes with the same immutable receipt")
	runtime._process(config.processing_duration_seconds * 4.0)
	_check(InventoryManager.get_count(species.yield_item) == before_item
		and receipts.size() == 1 and runtime.current_state() == MechanicalSplitterRuntime.State.READY
		and GameState.get_cash() == before_cash + expected_cash
		and GameState.get_xp() == before_xp + expected_xp,
		"a completed receipt cannot pay cash or XP twice and the empty slot returns ready")
	_check(GameState.get_species_mastery_progress(species.id) == before_mastery
		and GameState.get_lifetime_wood_chopped() == before_lifetime
		and order_started
		and GameState.get_active_order_progress() == before_order_progress,
		"automation XP grants no order progress, mastery, certification, lifetime chopped or manual completion progress")
	runtime.queue_free()
	await get_tree().process_frame


func _test_splitter_restore_safety() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var profile := _MechanicalSplitter.profile_definitions()[0]
	var save_shape := _splitter_runtime_save_shape(profile)
	GameState.apply_save_dict(save_shape)
	var species := SpeciesTable.by_id(profile.automation_species_id)
	var runtime := MechanicalSplitterRuntime.new()
	add_child(runtime)
	await get_tree().process_frame
	runtime.set_yard_active(true)
	var before := InventoryManager.get_count(species.yield_item)
	_check(runtime.try_queue_assigned_input(),
		"restore safety setup starts one watched in-memory cycle")
	runtime._process(runtime.config.processing_duration_seconds * 0.6)
	GameState.apply_save_dict(save_shape)
	_check(runtime.current_state() == MechanicalSplitterRuntime.State.READY
		and runtime.queued_count() == 0 and is_zero_approx(runtime.progress())
		and InventoryManager.get_count(species.yield_item) == before,
		"restoring progression discards ephemeral queue/progress without granting output")
	runtime._process(runtime.config.processing_duration_seconds * 2.0)
	_check(InventoryManager.get_count(species.yield_item) == before,
		"restored runtime cannot finish discarded work or create free output")
	runtime.queue_free()
	await get_tree().process_frame


func _test_splitter_species_ladder_samples() -> void:
	var profiles := _MechanicalSplitter.profile_definitions()
	for index in [0, 12, 24]:
		GameState.reset_to_defaults()
		InventoryManager.apply_save_dict({})
		var profile: UpgradeDef = profiles[index]
		var species := SpeciesTable.by_id(profile.automation_species_id)
		GameState.apply_save_dict(_splitter_runtime_save_shape(profile))
		var jobs_curve := GameConfig.current().level_curve
		GameState.add_xp(jobs_curve.total_xp_for_level(Orders.JOBS_UNLOCK_LEVEL))
		var unrelated := Orders.by_id(&"campfire_warmup")
		if unrelated != null and not GameState.has_completed_order(unrelated.id):
			GameState.accept_order(unrelated.id)
		var order_progress := GameState.get_active_order_progress()
		var runtime := MechanicalSplitterRuntime.new()
		add_child(runtime)
		await get_tree().process_frame
		runtime.set_yard_active(true)
		var expected_cash := Market.get_price(species.yield_item) \
			* runtime.effective_output_amount()
		var expected_xp := int(round(float(species.xp_reward \
			* runtime.effective_logs_per_split()) * runtime.automation_xp_rate() \
			* GameConfig.current().xp_pacing.global_xp_multiplier))
		var cash_before := GameState.get_cash()
		var xp_before := GameState.get_xp()
		var lifetime_before := GameState.get_lifetime_wood_chopped()
		var completed_before: Array = GameState.to_save_dict().get("completed_orders", []).duplicate()
		var completed := runtime.try_queue_assigned_input()
		runtime._process(runtime.effective_duration_seconds())
		completed = completed and runtime.last_cash_earned() == expected_cash \
			and runtime.last_xp_earned() == expected_xp \
			and GameState.get_cash() == cash_before + expected_cash \
			and GameState.get_xp() == xp_before + expected_xp \
			and GameState.get_lifetime_wood_chopped() == lifetime_before \
			and GameState.get_active_order_progress() == order_progress \
			and GameState.to_save_dict().get("completed_orders", []) == completed_before
		_check(completed,
			"%s completes an exact watched cycle without manual progression leakage" % species.display_name)
		runtime.queue_free()
		await get_tree().process_frame


func _test_splitter_upgrade_catalogue_and_pacing() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var definitions := _MechanicalSplitter.upgrade_definitions()
	var effects: Array[UpgradeDef.Effect] = []
	var labelled := true
	for definition: UpgradeDef in definitions:
		effects.append(definition.effect)
		labelled = labelled and definition.tuning_status.begins_with("APPROVED")
	var speed := _MechanicalSplitter.upgrade_definition(UpgradeDef.Effect.AUTOMATION_SPEED)
	var auto_load := _MechanicalSplitter.upgrade_definition(UpgradeDef.Effect.AUTOMATION_AUTO_LOAD)
	var logs := _MechanicalSplitter.upgrade_definition(UpgradeDef.Effect.AUTOMATION_LOGS_PER_SPLIT)
	var xp := _MechanicalSplitter.upgrade_definition(UpgradeDef.Effect.AUTOMATION_XP_GAIN)
	var cash := _MechanicalSplitter.upgrade_definition(UpgradeDef.Effect.AUTOMATION_CASH_GAIN)
	var exact_tuning := speed != null and speed.base_cost == 500 \
		and is_equal_approx(speed.cost_growth, 1.5) and speed.max_level == 5 \
		and is_equal_approx(speed.effect_step, 0.1) \
		and auto_load != null and auto_load.base_cost == 2500 \
		and is_equal_approx(auto_load.cost_growth, 1.0) and auto_load.max_level == 1 \
		and is_equal_approx(auto_load.effect_step, 1.0) \
		and logs != null and logs.base_cost == 1000 \
		and is_equal_approx(logs.cost_growth, 1.4) and logs.max_level == 7 \
		and is_equal_approx(logs.effect_step, 1.0) \
		and xp != null and xp.base_cost == 1000 \
		and is_equal_approx(xp.cost_growth, 1.5) and xp.max_level == 4 \
		and is_equal_approx(xp.effect_step, 0.2) \
		and cash != null and cash.base_cost == 750 \
		and is_equal_approx(cash.cost_growth, 1.5) and cash.max_level == 5 \
		and is_equal_approx(cash.effect_step, 0.1)
	_check(effects == [UpgradeDef.Effect.AUTOMATION_SPEED,
		UpgradeDef.Effect.AUTOMATION_AUTO_LOAD,
		UpgradeDef.Effect.AUTOMATION_LOGS_PER_SPLIT,
		UpgradeDef.Effect.AUTOMATION_XP_GAIN,
		UpgradeDef.Effect.AUTOMATION_CASH_GAIN] and labelled and exact_tuning,
		"the five splitter lines preserve Sam's exact approved prices, ranks and effects")

	var profile := _MechanicalSplitter.profile_definitions()[0]
	var progression := _splitter_runtime_save_shape(profile)
	var owned_tiers: Dictionary = progression["building_tiers"]
	for id: StringName in [GameState.UPGRADE_BALANCED_AXE,
		GameState.UPGRADE_REINFORCED_BLOCK, GameState.UPGRADE_SUPPLIER_LEDGER,
		GameState.UPGRADE_HANDCART, GameState.UPGRADE_COFFEE_THERMOS]:
		owned_tiers[String(id)] = GameState.DEFAULT_BUILDING_TIER + 1
	GameState.apply_save_dict(progression)
	_set_mastery_for_species(3)
	_check(Shop.is_visible(speed.id) and Shop.is_unlocked(speed.id)
		and not Shop.is_unlocked(auto_load.id) and not Shop.is_visible(auto_load.id),
		"Speed introduces first while the unearned Auto Loading row stays hidden")
	GameState.add_cash(100000)
	var chain_ok := Shop.buy(speed.id) == 1 and Shop.is_unlocked(auto_load.id) \
		and Shop.buy(auto_load.id) == 1 and Shop.is_unlocked(logs.id) \
		and Shop.buy(logs.id) == 1 and Shop.is_unlocked(xp.id) \
		and Shop.buy(xp.id) == 1 and Shop.is_unlocked(cash.id)
	_check(chain_ok,
		"the paced chain reveals Auto Loading, Logs per Split, XP, then Money in order")


func _test_splitter_upgrade_runtime() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var profile := _MechanicalSplitter.profile_definitions()[0]
	var data := _splitter_runtime_save_shape(profile)
	var tiers: Dictionary = data["building_tiers"]
	for effect: UpgradeDef.Effect in [UpgradeDef.Effect.AUTOMATION_SPEED,
		UpgradeDef.Effect.AUTOMATION_AUTO_LOAD,
		UpgradeDef.Effect.AUTOMATION_LOGS_PER_SPLIT,
		UpgradeDef.Effect.AUTOMATION_XP_GAIN,
		UpgradeDef.Effect.AUTOMATION_CASH_GAIN]:
		var definition := _MechanicalSplitter.upgrade_definition(effect)
		tiers[String(definition.id)] = GameState.DEFAULT_BUILDING_TIER + 1
	GameState.apply_save_dict(data)
	var species := SpeciesTable.by_id(profile.automation_species_id)
	var runtime := MechanicalSplitterRuntime.new()
	add_child(runtime)
	await get_tree().process_frame
	_check(runtime.auto_loading_enabled()
		and runtime.effective_duration_seconds() < runtime.config.processing_duration_seconds
		and runtime.effective_logs_per_split() == 6
		and is_equal_approx(runtime.automation_xp_rate(), 0.40)
		and is_equal_approx(runtime.automation_cash_bonus(), 0.10),
		"one rank of each line changes speed, auto loading, batch size, XP and cash independently")
	runtime.set_yard_active(true)
	runtime._process(0.001)
	_check(runtime.current_state() == MechanicalSplitterRuntime.State.PROCESSING
		and runtime.queued_count() == 1,
		"Auto Loading fills the same bounded slot without adding a second queue")
	var expected_amount := runtime.effective_output_amount()
	var expected_cash := int(round(float(Market.get_price(species.yield_item)
		* expected_amount) * 1.10))
	var expected_xp := int(round(float(species.xp_reward * 6) * 0.40 \
		* GameConfig.current().xp_pacing.global_xp_multiplier))
	runtime._process(runtime.effective_duration_seconds())
	_check(runtime.last_logs_processed() == 6
		and runtime.last_cash_earned() == expected_cash
		and runtime.last_xp_earned() == expected_xp
		and InventoryManager.get_count(species.yield_item) == 0,
		"upgraded represented batch sells once with its own Money and XP multipliers")
	runtime.queue_free()
	await get_tree().process_frame


func _test_splitter_runtime_presentation() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var profile := _MechanicalSplitter.profile_definitions()[0]
	GameState.apply_save_dict(_splitter_runtime_save_shape(profile))
	var game: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	game.debug_forced_species = 0
	add_child(game)
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	await get_tree().process_frame
	var runtime: MechanicalSplitterRuntime = game.get_node("MechanicalSplitterRuntime")
	runtime.set_yard_active(true)
	hud.bind_splitter_runtime(runtime)
	hud.bind_xp_source(game)
	var presenter: YardEquipmentPresenter = game.get_node("YardEquipment")
	var rewards: SplitterRewardPresenter = game.get_node("SplitterRewardPresenter")
	var manual_coin_pool: Node = game.get_node("CoinRewardPool")
	var splitter_coin_pool: Node = rewards.get_node("SplitterCoinPool")
	var splitter_orb_pool: Node = rewards.get_node("SplitterXPOrbPool")
	var machine := presenter.get_node_or_null("mechanical_splitter")
	var art_label: Label3D = presenter.get_node_or_null(
		"mechanical_splitter/MissingArtAndStateLabel")
	var world_state_label: Label3D = presenter.get_node_or_null(
		"mechanical_splitter/OperationalStateLabel")
	var representative_log: MeshInstance3D = presenter.get_node_or_null(
		"mechanical_splitter/RepresentativeAssignedLog")
	_check(machine != null
		and machine.get_meta("art_status", "") ==
			"placeholder_graphic_integrated_pending_final_3d_asset"
		and art_label != null and art_label.text.contains("PLACEHOLDER")
		and machine.get_node_or_null("MechanicalSplitterGraphic") != null
		and world_state_label != null and art_label.font_size < world_state_label.font_size
		and representative_log != null
		and representative_log.get_meta("art_status", "") ==
			"single_preauthored_log_proxy_no_runtime_slicing",
		"the purchased machine pairs replaceable geometry with a readable placeholder graphic")
	_check(manual_coin_pool != splitter_coin_pool
			and manual_coin_pool.get_child_count() == 40
			and splitter_coin_pool.get_child_count() == 40
			and splitter_orb_pool.get_child_count() == 10
			and rewards.get_node_or_null("SplitterChip11") != null,
		"manual and splitter cash/XP/chip effects use separate bounded prewarmed pools")
	var skin := representative_log.material_override as StandardMaterial3D
	var inside_skin := representative_log.get_node("InsideEnd0").material_override \
		as StandardMaterial3D
	var species := SpeciesTable.by_id(profile.automation_species_id)
	_check(skin != null and inside_skin != null and species != null
			and skin.albedo_color == species.bark_tint
			and inside_skin.albedo_color == species.inside_tint,
		"the representative splitter log separates assigned-species bark and inside treatments")
	var state_label: Label = hud.get_node("SplitterRuntimeCard/Column/State")
	var detail: Label = hud.get_node("SplitterRuntimeCard/Column/Detail")
	var action: Button = hud.get_node("SplitterRuntimeCard/Column/Action")
	var cash_label: Label = hud.get_node("TopBar/CashRow/CashLabel")
	var xp_progress: ProgressBar = hud.get_node("XPBar/Progress")
	var cash_before := GameState.get_cash()
	var xp_before := GameState.get_xp()
	_check(state_label.text == "READY" and detail.text.contains("5 log batch")
		and not action.disabled and action.text == "Load assigned log",
		"the always-on runtime card legibly shows the ready assigned species and action")
	action.pressed.emit()
	runtime._process(runtime.config.processing_duration_seconds * 0.5)
	await get_tree().process_frame
	_check(state_label.text == "PROCESSING"
		and action.text.contains("Input slot full")
		and hud.get_node("SplitterRuntimeCard/Column/Progress").value > 0.0
		and representative_log.visible,
		"the runtime card and one representative log show the active processing batch")
	runtime._process(runtime.config.processing_duration_seconds)
	var chips_visible := false
	for index in range(12):
		chips_visible = chips_visible or rewards.get_node("SplitterChip%d" % index).visible
	_check(GameState.get_cash() > cash_before and GameState.get_xp() > xp_before
			and cash_label.text == str(cash_before)
			and is_equal_approx(xp_progress.value,
				GameState.get_level_progress_for_xp(xp_before))
			and chips_visible,
		"successful settlement is authoritative immediately while exact cash/XP remain visually pending and chips burst")
	# Presentation timing is deliberately replaceable. Wait for the bounded exact
	# receipt contract instead of pinning this legacy suite to one old duration.
	for _frame in range(60):
		if state_label.text == "READY" \
				and cash_label.text == String(hud.call(
					"_compact_number", GameState.get_cash())) \
				and absf(xp_progress.value \
					- GameState.get_level_progress_for_xp(GameState.get_xp())) < 0.001:
			break
		await get_tree().create_timer(0.05).timeout
	# Equipment presentation is rebuilt from live ownership/state signals. Do not
	# retain a stale node reference across that rebuild; assert against the current
	# representative log owned by the presenter.
	representative_log = presenter.get_node_or_null(
		"mechanical_splitter/RepresentativeAssignedLog")
	_check(state_label.text == "READY"
		and representative_log != null and not representative_log.visible
		and hud.get_node("SplitterRuntimeCard/Column/Receipt").text.contains("cash")
		and hud.get_node("SplitterRuntimeCard/Column/Receipt").text.contains("XP")
		and cash_label.text == String(hud.call("_compact_number", GameState.get_cash()))
		and absf(xp_progress.value \
			- GameState.get_level_progress_for_xp(GameState.get_xp())) < 0.001,
		"the watched UI returns ready and exact pooled receipts reconcile both counters " \
		+ "[state=%s log=%s receipt=%s cash=%s/%s xp=%.3f/%.3f]" % [
			state_label.text,
			"missing" if representative_log == null else str(representative_log.visible),
			hud.get_node("SplitterRuntimeCard/Column/Receipt").text,
			cash_label.text, String(hud.call("_compact_number", GameState.get_cash())),
			xp_progress.value, GameState.get_level_progress_for_xp(GameState.get_xp())])
	hud.queue_free()
	game.queue_free()
	await get_tree().process_frame


func _splitter_runtime_save_shape(profile: UpgradeDef) -> Dictionary:
	var machine := _MechanicalSplitter.machine_definition()
	var target: int = M7CContent.mastery().by_species_id(
		profile.automation_species_id).mastery_target
	var data := {
		"building_tiers": {
			String(machine.id): GameState.DEFAULT_BUILDING_TIER + 1,
			String(profile.id): GameState.DEFAULT_BUILDING_TIER + 1,
		},
		"species_mastery_progress": {
			String(profile.automation_species_id): target,
		},
		"splitter_assigned_species": String(profile.automation_species_id),
	}
	if profile.unlock_order_id != &"":
		data["completed_orders"] = [String(profile.unlock_order_id)]
	return data


func _set_mastery_for_species(count: int) -> void:
	var progress: Dictionary = {}
	var table := M7CContent.mastery()
	for index in range(mini(count, SpeciesTable.count())):
		var species := SpeciesTable.at(index)
		var definition: SpeciesMasteryDef = table.by_species_id(species.id) \
			if table != null and species != null else null
		if definition != null:
			progress[String(species.id)] = definition.mastery_target
	var current: Dictionary = GameState.to_save_dict()
	current["species_mastery_progress"] = progress
	GameState.apply_save_dict(current)


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


func _control_text_under(root: Node) -> String:
	var out := ""
	if root is Label:
		out += (root as Label).text + "\n"
	elif root is Button:
		out += (root as Button).text + "\n"
	for child: Node in root.get_children():
		out += _control_text_under(child)
	return out


func _find_button_with_text(root: Node, wanted: String) -> Button:
	if root is Button and (root as Button).text == wanted:
		return root as Button
	for child: Node in root.get_children():
		var found := _find_button_with_text(child, wanted)
		if found != null:
			return found
	return null


func _button_count(root: Node) -> int:
	var count := 1 if root is Button else 0
	for child: Node in root.get_children():
		count += _button_count(child)
	return count


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
