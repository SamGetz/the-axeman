extends Node
## Focused four-hour campaign foundation: depletion, gross earnings and v16.

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== M15 ACCEPTANCE — Pacing Foundation ===")
	_test_fresh_state_and_cash_authority()
	_test_first_use_reveal_authority()
	_test_manual_and_receipt_depletion()
	_test_final_receipt_and_exhaustion()
	_test_company_simulation_caps_before_output()
	_test_reinvestment_catalogue_and_composition()
	_test_continuity_reserve_guard()
	_test_continuity_reserve_prepays_launch_spine()
	_test_planetary_projection_and_overflow_headroom()
	_test_complete_campaign_time_projection()
	_test_offline_return_reaches_zero_once()
	_test_v16_migration_and_round_trip()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	print("=== M15 RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL M15 PACING FOUNDATION CRITERIA PASS ===")
	get_tree().quit(1 if _fails > 0 else 0)


func _test_fresh_state_and_cash_authority() -> void:
	GameState.reset_to_defaults()
	_check(GameState.get_earth_trees_remaining() == 3_040_000_000_000 \
		and GameState.get_earth_trees_felled() == 0 \
		and GameState.get_lifetime_cash_earned() == 0,
		"a fresh yard begins with the approved exact Earth total and no gross earnings")
	_check(GameState.add_cash(100) and GameState.get_lifetime_cash_earned() == 0,
		"setup and migration grants do not enter lifetime gameplay earnings")
	_check(GameState.award_cash(40, &"acceptance") == 40 \
		and GameState.get_lifetime_cash_earned() == 40 \
		and GameState.try_spend_cash(25) \
		and GameState.get_lifetime_cash_earned() == 40,
		"credited gameplay cash raises a monotonic reveal authority that spending cannot lower")
	GameState.reset_to_defaults()
	var band_changes: Array[Vector2i] = []
	GameState.earnings_band_changed.connect(func(previous: int, next: int) -> void:
		band_changes.append(Vector2i(previous, next)), CONNECT_ONE_SHOT)
	GameState.award_cash(199999, &"acceptance")
	GameState.award_cash(1, &"acceptance")
	GameState.try_spend_cash(100000)
	_check(band_changes == [Vector2i(0, 1)] and GameState.get_earnings_band() == 1,
		"crossing a gross-earnings boundary emits once and spending cannot reverse the band")


func _test_first_use_reveal_authority() -> void:
	GameState.reset_to_defaults()
	var curve := GameConfig.current().level_curve
	var cost := Shop.opening_unlock_cost()
	GameState.award_cash(cost, &"acceptance")
	_check(cost == 50 and not Orders.jobs_unlocked() \
		and not Shop.is_entry_revealed() \
		and Shop.buy(&"balanced_axe") == -1,
		"cash alone cannot bypass either first-use progression gate")
	GameState.add_xp(curve.total_xp_for_level(Orders.JOBS_UNLOCK_LEVEL))
	_check(Orders.jobs_unlocked() and not Shop.is_entry_revealed() \
		and Shop.buy(&"balanced_axe") == -1,
		"level 3 unlocks Jobs while the Shop still refuses purchases")
	var first := Orders.by_id(&"campfire_warmup")
	_check(first != null and GameState.accept_order(first.id),
		"the first authored job can be accepted once Jobs unlock")
	for _piece in range(first.required_count):
		GameState.record_order_piece(&"birch_firewood")
	_check(GameState.has_completed_order(first.id) and Shop.is_entry_revealed() \
		and Shop.buy(&"balanced_axe") == 1,
		"completing one job reveals the Shop and authorises its first purchase")


func _test_manual_and_receipt_depletion() -> void:
	GameState.reset_to_defaults()
	var first_three := true
	for index in range(3):
		first_three = first_three and GameState.record_manual_log_equivalent(
			StringName("foundation_manual_%d" % index))
	_check(first_three and GameState.get_earth_trees_felled() == 0 \
		and GameState.get_manual_logs_toward_next_tree() == 3 \
		and GameState.record_manual_log_equivalent(&"foundation_manual_3") \
		and not GameState.record_manual_log_equivalent(&"foundation_manual_3") \
		and GameState.get_earth_trees_felled() == 1 \
		and GameState.get_manual_log_equivalents() == 4 \
		and GameState.get_manual_logs_toward_next_tree() == 0,
		"four unique completed manual logs fell one Earth tree exactly once")
	var watched := EarthProductionDelta.new(&"foundation_watched",
		EarthProductionDelta.SourceKind.WATCHED_SPLITTER,
		{&"quaking_aspen": 12}, {&"aspen_firewood": 12})
	_check(GameState.can_apply_earth_production(watched) \
		and GameState.apply_earth_production(watched) \
		and not GameState.apply_earth_production(watched) \
		and GameState.get_earth_trees_felled() == 13 \
		and GameState.get_automated_log_equivalents() == 12,
		"typed watched receipts keep tree and output facts separate and apply once")


func _test_final_receipt_and_exhaustion() -> void:
	var remaining := GameState.get_earth_trees_remaining()
	_check(GameState.preview_earth_tree_felling(remaining + 99) == remaining,
		"the final production preview clamps before nonexistent trees create output")
	var oversized := EarthProductionDelta.new(&"foundation_oversized",
		EarthProductionDelta.SourceKind.COMPANY_ACTIVE,
		{&"quaking_aspen": remaining + 1})
	var final := EarthProductionDelta.new(&"foundation_final",
		EarthProductionDelta.SourceKind.COMPANY_ACTIVE,
		{&"quaking_aspen": remaining})
	_check(not GameState.can_apply_earth_production(oversized) \
		and GameState.apply_earth_production(final) \
		and GameState.is_earth_depleted() and GameState.is_earth_master() \
		and GameState.get_earth_trees_remaining() == 0,
		"only the capped exact final receipt reaches zero and opens the endgame")
	_check(not GameState.record_manual_log_equivalent(&"after_zero") \
		and not GameState.record_watched_automation_logs(1, &"after_zero_watched",
			&"quaking_aspen"),
		"terrestrial manual and watched sources refuse new production after zero")
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	_check(hud.get_node("EarthTreesRemaining").text == "Earth · 0 trees remaining",
		"the live HUD retains the subtle exact bottom-left zero-tree counter")
	hud.queue_free()


func _test_company_simulation_caps_before_output() -> void:
	var receipt := CompanySimulation.simulate({
		"last_timestamp": 0,
		"queues": {&"quaking_aspen": 20},
		"route_priorities": [&"quaking_aspen"],
		"dispatch_capacity": 10,
		"earth_trees_remaining": 2,
	}, 60, true)
	_check(receipt.processed_logs() == 2 \
		and int(receipt.outputs.get(&"aspen_firewood", 0)) == 2 \
		and int(receipt.remaining_queues.get(&"quaking_aspen", 0)) == 18,
		"active/offline simulation caps trees before it derives output or remaining queues")


func _test_reinvestment_catalogue_and_composition() -> void:
	GameState.reset_to_defaults()
	var production_defs: Array[ProductionUpgradeDef] = []
	for upgrade: UpgradeDef in Shop.get_upgrades():
		if upgrade is ProductionUpgradeDef:
			production_defs.append(upgrade as ProductionUpgradeDef)
	_check(production_defs.size() == 16 and production_defs.all(
		func(def: ProductionUpgradeDef) -> bool:
			return def.validate_production().is_empty()),
		"all sixteen bounded reinvestment items retain explicit four-hour placeholders")
	_check(not Shop.is_visible(&"parallel_splitter_bay"),
		"an earnings threshold cannot advertise machinery before its depot milestone")
	var tiers := {
		&"mechanical_splitter": 2,
		&"log_feeder": 2,
		&"yard_sweeper": 2,
		&"auto_stacker": 2,
		&"order_router": 2,
		&"maintenance_package": 2,
		&"dispatch_console": 2,
	}
	GameState.apply_save_dict({
		"cash": 1000000,
		"lifetime_cash_earned": 1000000,
		"automated_log_equivalents": 1,
		"building_tiers": tiers,
	})
	var first_cost := Shop.get_next_cost(&"parallel_splitter_bay")
	_check(Shop.is_visible(&"parallel_splitter_bay") and first_cost == 120000 \
		and Shop.buy(&"parallel_splitter_bay") == 1 \
		and Shop.get_next_cost(&"parallel_splitter_bay") == 288000 \
		and GameState.get_lifetime_cash_earned() == 1000000,
		"a milestone plus monotonic earnings reveals a fixed-price rank that spending cannot rebase")
	GameState.apply_save_dict({
		"cash": 1,
		"lifetime_cash_earned": 1000000,
		"automated_log_equivalents": 1,
		"building_tiers": tiers.merged({
			&"parallel_splitter_bay": 4,
			&"recovery_saw_bench": 4,
		}, true),
	})
	var receipt := CompanySimulation.simulate({
		"last_timestamp": 0,
		"queues": {&"quaking_aspen": 24},
		"route_priorities": [&"quaking_aspen"],
		"dispatch_capacity": 1,
		"parallel_lines": ProductionEconomy.effective_parallel_lines(),
		"logs_per_tree": ProductionEconomy.logs_per_tree(),
		"earth_trees_remaining": 24,
	}, 5, false)
	_check(receipt.processed_logs() == 4 \
		and int(receipt.outputs.get(&"aspen_firewood", 0)) == 12,
		"parallel lines and recovery output compose while depletion remains based on four trees")


func _test_continuity_reserve_guard() -> void:
	GameState.apply_save_dict({
		"cash": 100000000000000,
		"lifetime_cash_earned": 100000000000000,
		"building_tiers": {
			&"satellite_forest_survey": 2,
			&"planetary_dispatch_core": 5,
		},
	})
	_check(Shop.buy(&"planetary_dispatch_core") == -1,
		"the final planetary dispatch rank refuses unreserved launch capital")
	GameState.apply_save_dict({
		"cash": 100000000000000,
		"lifetime_cash_earned": 100000000000000,
		"building_tiers": {
			&"satellite_forest_survey": 2,
			&"continuity_reserve": 2,
			&"planetary_dispatch_core": 5,
		},
	})
	_check(Shop.buy(&"planetary_dispatch_core") == 5 \
		and ProductionEconomy.has_continuity_reserve(),
		"an owned Continuity Reserve makes the final terrestrial multiplier atomic and restorable")


func _test_continuity_reserve_prepays_launch_spine() -> void:
	var mastery: Dictionary = {}
	for species: SpeciesDef in SpeciesTable.all():
		mastery[species.id] = M7CContent.mastery().by_species_id(
			species.id).mastery_target
	GameState.apply_save_dict({
		"cash": 0,
		"lifetime_cash_earned": 20000000000,
		"automated_log_equivalents": 400000,
		"earth_trees_felled": GameState.TOTAL_EARTH_TREES,
		"earth_master": true,
		"earth_finale_state": GameState.EarthFinaleState.COMPLETE,
		"earth_finale_splits": 3,
		"species_mastery_progress": mastery,
		"building_tiers": {&"continuity_reserve": 2},
	})
	var launched := true
	for project: LaunchProjectDef in LaunchProgram.projects():
		launched = launched and GameState.get_launch_contribution(project.id) \
			== project.contribution_amount \
			and GameState.complete_launch_project(project.id)
	_check(launched and GameState.get_cash() == 0 \
		and GameState.has_launch_project(&"deep_space_vessel"),
		"the prepaid reserve preserves the sequential launch spine at zero spendable cash")


func _test_planetary_projection_and_overflow_headroom() -> void:
	var tiers := {
		&"hydraulic_split_banks": 2,
		&"parallel_splitter_bay": 6,
		&"recovery_saw_bench": 5,
		&"commercial_grading_desk": 5,
		&"depot_power_drive": 6,
		&"rail_consist_expansion": 6,
		&"port_crane_array": 6,
		&"automated_species_router": 6,
		&"satellite_forest_survey": 2,
		&"autonomous_harvest_fleet": 6,
		&"global_mill_network": 6,
		&"continuity_reserve": 2,
		&"planetary_dispatch_core": 6,
	}
	var mastery: Dictionary = {}
	var planetary_species: Array[StringName] = []
	for species: SpeciesDef in SpeciesTable.all():
		mastery[species.id] = M7CContent.mastery().by_species_id(
			species.id).mastery_target
		planetary_species.append(species.id)
	GameState.apply_save_dict({
		"cash": 1,
		"lifetime_cash_earned": 1000000000000000,
		"building_tiers": tiers,
		"species_mastery_progress": mastery,
	})
	var input := GameState.get_company_simulation_input()
	input.last_timestamp = 0
	input.planetary_species = planetary_species
	var at_16_5 := CompanySimulation.simulate(input, 990, false)
	var at_17 := CompanySimulation.simulate(input, 1020, false)
	var output_total := 0
	for amount: Variant in at_17.outputs.values():
		output_total += int(amount)
	_check(at_16_5.processed_logs() > 3000000000000 \
		and at_16_5.processed_logs() < GameState.TOTAL_EARTH_TREES \
		and at_17.processed_logs() == GameState.TOTAL_EARTH_TREES,
		"the provisional maximum planetary set crosses zero in a 16.5–17 minute endgame band")
	_check(output_total > GameState.TOTAL_EARTH_TREES \
		and output_total < GameState.MAX_SAFE_ECONOMY_VALUE,
		"the full planetary recovery set creates huge output with signed-64-bit headroom")


func _test_offline_return_reaches_zero_once() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	GameState.apply_save_dict({
		"cash": 0,
		"earth_trees_felled": GameState.TOTAL_EARTH_TREES - 2,
	})
	var receipt := CompanySimulation.simulate({
		"last_timestamp": 0,
		"queues": {&"quaking_aspen": 20},
		"route_priorities": [&"quaking_aspen"],
		"dispatch_capacity": 10,
		"earth_trees_remaining": 2,
	}, 60, true)
	_check(receipt.offline and receipt.processed_logs() == 2 \
		and CompanyLogistics.apply_receipt(receipt) \
		and GameState.is_earth_depleted() \
		and not CompanyLogistics.apply_receipt(receipt),
		"an offline return caps at zero, settles on return and cannot replay its transition")


func _test_complete_campaign_time_projection() -> void:
	var curve := GameConfig.current().level_curve
	var config := GameConfig.current().xp_pacing
	var total_xp := 0
	var terrestrial_seconds := 0.0
	var species := SpeciesTable.all()
	for index in range(species.size()):
		var wood: SpeciesDef = species[index]
		var logs := M7CContent.mastery().by_species_id(wood.id).mastery_target
		var awarded_xp := maxi(1, int(round(float(wood.xp_reward) \
			* config.global_xp_multiplier)))
		if index + 1 < species.size():
			var next_wood: SpeciesDef = species[index + 1]
			var target_xp := curve.total_xp_for_level(next_wood.unlock_level)
			while total_xp + logs * awarded_xp < target_xp:
				logs += 1
		total_xp += logs * awarded_xp
		terrestrial_seconds += logs * float(
			config.representative_terrestrial_active_seconds[index])
	var frontier_seconds := 0.0
	var alien := AlienCampaign.traits()
	for index in range(alien.size()):
		frontier_seconds += alien[index].manual_mastery_target * float(
			config.representative_alien_active_seconds[index])
	for destination: ExpeditionDef in LaunchProgram.expedition_table().expeditions:
		frontier_seconds += destination.flight_seconds
	# The planetary projection reaches zero on the cycle immediately after the
	# 990-second lower-bound snapshot. Twenty minutes is then reserved for UI,
	# reading, purchasing and route decisions rather than productive chopping.
	var conservative_total := terrestrial_seconds + 995.0 + frontier_seconds + 1200.0
	_check(terrestrial_seconds >= 90.0 * 60.0 \
		and terrestrial_seconds < 150.0 * 60.0 \
		and conservative_total >= 120.0 * 60.0 \
		and conservative_total <= 240.0 * 60.0,
		"the no-bonus critical path starts quickly, slows into the finale and remains inside 2–4 hours")


func _test_v16_migration_and_round_trip() -> void:
	var legacy_master := SaveSystem._migrate({
		"cash": 77,
		"earth_finale_state": GameState.EarthFinaleState.COMPLETE,
		"earth_finale_splits": 3,
		"earth_master": true,
	}, 14)
	var legacy_active := SaveSystem._migrate({
		"cash": 41,
		"manual_log_equivalents": 3,
		"automated_log_equivalents": 9,
		"earth_master": false,
	}, 14)
	var owned_band := SaveSystem._migrate({
		"cash": 1,
		"building_tiers": {"parallel_splitter_bay": 2},
	}, 14)
	var v15_partial := SaveSystem._migrate({
		"manual_log_equivalents": 7,
		"earth_trees_felled": 7,
	}, 15)
	_check(int(legacy_master.get("earth_trees_felled", -1)) \
			== GameState.TOTAL_EARTH_TREES \
		and int(legacy_master.get("lifetime_cash_earned", -1)) == 77 \
		and int(legacy_active.get("earth_trees_felled", -1)) == 9 \
		and int(legacy_active.get("lifetime_cash_earned", -1)) == 41 \
		and int(owned_band.get("lifetime_cash_earned", -1)) == 200000 \
		and int(v15_partial.get("earth_trees_felled", -1)) == 7 \
		and int(v15_partial.get("manual_logs_toward_next_tree", -1)) == 0,
		"v16 preserves committed v15 trees and conservatively converts older manual work")
	GameState.apply_save_dict(legacy_active)
	var snapshot := GameState.to_save_dict()
	GameState.reset_to_defaults()
	GameState.apply_save_dict(snapshot)
	_check(GameState.get_earth_trees_felled() == 9 \
		and GameState.get_lifetime_cash_earned() == 41 \
		and GameState.get_manual_logs_toward_next_tree() == 0 \
		and not GameState.is_earth_master(),
		"v16 depletion, partial manual progress and earnings round-trip without inventing access")
	GameState.apply_save_dict({
		"cash": 1,
		"lifetime_cash_earned": 1,
		"building_tiers": {"parallel_splitter_bay": 2},
	})
	_check(GameState.get_lifetime_cash_earned() == 200000 \
		and GameState.get_cash() == 1,
		"owned production ranks restore their minimum reveal band without granting spendable cash")


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)
