extends Node
## Focused M11 global wood mastery acceptance.

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== M11 ACCEPTANCE — Global Wood Mastery Campaign ===")
	_test_world_catalogue()
	_test_separate_company_totals()
	_test_anti_stall_goal_and_projects()
	_test_offline_story_exclusion()
	await _test_catalogue_ui()
	GameState.reset_to_defaults()
	print("=== M11 RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL M11 ACCEPTANCE CRITERIA PASS ===")
	get_tree().quit()


func _test_world_catalogue() -> void:
	GameState.reset_to_defaults()
	var rows := EarthCampaign.catalogue_rows()
	var valid := rows.size() == 25
	var sourced: Dictionary = {}
	for row: Dictionary in rows:
		valid = valid and row.has("owned") and row.has("manual_mastery") \
			and row.has("certified") and row.has("supplier") \
			and row.has("contract_complete") and row.has("automation")
		sourced[StringName(row.species_id)] = StringName(row.supplier)
	_check(valid and sourced.size() == 25 and not sourced.values().has(&""),
		"the World Wood Catalogue exposes all 25 species and six required statuses")


func _test_separate_company_totals() -> void:
	GameState.apply_save_dict({"automated_log_equivalents": 7})
	_check(GameState.record_manual_log_equivalent(&"manual_a")
		and not GameState.record_manual_log_equivalent(&"manual_a")
		and GameState.record_manual_log_equivalent(&"manual_b"),
		"manual source-log identities are monotonic and de-duplicated")
	_check(GameState.get_manual_log_equivalents() == 2
		and GameState.get_automated_log_equivalents() == 7
		and GameState.get_combined_company_log_total() == 9,
		"manual and automated source-log equivalents remain separate with one readable total")
	var snapshot := GameState.to_save_dict()
	GameState.reset_to_defaults()
	GameState.apply_save_dict(snapshot)
	_check(GameState.get_manual_log_equivalents() == 2
		and not GameState.record_manual_log_equivalent(&"manual_a"),
		"manual totals and bounded recent source identities round-trip")


func _test_anti_stall_goal_and_projects() -> void:
	GameState.reset_to_defaults()
	var goal := EarthCampaign.next_anti_stall_goal()
	_check(String(goal.kind) in ["own", "master"] and goal.has("species_id"),
		"the next unowned or unmastered species is an explicit anti-stall goal")
	var project_count := 0
	for project_id: StringName in EarthCampaign.GLOBAL_PROJECT_IDS:
		var project := RegionalNetwork.project_by_id(project_id)
		if project != null and project.tuning_status.begins_with("PLACEHOLDER"):
			project_count += 1
	_check(project_count == 3,
		"World Catalogue Archive, Heavy Freight Grid and Global Buyer Exchange are provisional typed projects")
	var migrated := SaveSystem._migrate({"cash": 2}, 9)
	_check(int(migrated.get("manual_log_equivalents", -1)) == 0
		and (migrated.get("manual_log_sources") as Array).is_empty()
		and int(migrated.get("earth_finale_state", -1)) \
			== GameState.EarthFinaleState.LOCKED,
		"v9 to v10 migration invents no historical totals or Earth finale progress")


func _test_offline_story_exclusion() -> void:
	GameState.apply_save_dict({
		"supplier_input_queues": {"quaking_aspen": 4},
		"route_priorities": ["quaking_aspen"],
		"company_last_timestamp": 100,
	})
	var before_mastery := GameState.get_species_mastery_progress(&"quaking_aspen")
	var before_finale := GameState.get_earth_finale_state()
	var receipt := CompanySimulation.simulate(GameState.get_company_simulation_input(),
		100 + CompanySimulation.config().seconds_per_log * 4, true)
	_check(receipt.processed_logs() > 0
		and GameState.get_species_mastery_progress(&"quaking_aspen") == before_mastery
		and GameState.get_earth_finale_state() == before_finale,
		"offline receipts process bounded output without mastery, certification or story presentation")


func _test_catalogue_ui() -> void:
	GameState.reset_to_defaults()
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	hud.get_node("QuickMenu/TreesButton").pressed.emit()
	await get_tree().process_frame
	var list: VBoxContainer = hud.get_node("TreesPanel/Column/WoodScroll/WoodList")
	var title: Label = hud.get_node("TreesPanel/Column/Header/Title")
	_check(title.text == "World Wood Catalogue" and list.get_child_count() == 1,
		"the native catalogue hides every unavailable Earth species identity")
	hud.queue_free()
	await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)
