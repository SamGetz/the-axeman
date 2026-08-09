extends Node
## Focused M11B final terrestrial species acceptance.

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== M11B ACCEPTANCE — Final Terrestrial Species ===")
	_test_final_species_gate()
	_test_manual_multistage_finale()
	_test_corrupt_restore_cannot_complete()
	await _test_campaign_closure_memorial()
	GameState.reset_to_defaults()
	print("=== M11B RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL M11B ACCEPTANCE CRITERIA PASS ===")
	get_tree().quit()


func _test_final_species_gate() -> void:
	GameState.reset_to_defaults()
	_check(not GameState.can_species_be_bought(EarthCampaign.FINAL_SPECIES_ID),
		"Lignum Vitae cannot be bought before the terrestrial campaign requirements")
	GameState.apply_save_dict(_finale_ready_save(false))
	_check(EarthCampaign.terrestrial_requirements_complete()
		and GameState.get_earth_finale_state() == GameState.EarthFinaleState.READY,
		"the other 24 manual masteries and three global projects unlock the showcase")
	_check(GameState.can_species_be_bought(EarthCampaign.FINAL_SPECIES_ID)
		and GameState.try_buy_species(EarthCampaign.FINAL_SPECIES_ID),
		"the final ordinary cash purchase remains atomic after its campaign gate")
	_check(not GameState.select_species(EarthCampaign.FINAL_SPECIES_ID),
		"the showcase log cannot reach the block before the finale begins")


func _test_manual_multistage_finale() -> void:
	GameState.apply_save_dict(_finale_ready_save(true))
	_check(GameState.begin_earth_finale()
		and GameState.select_species(EarthCampaign.FINAL_SPECIES_ID),
		"the ready finale deliberately places the owned showcase log on the original block")
	var automated := ManualPieceReceipt.new(&"lignum_vitae_firewood",
		EarthCampaign.FINAL_SPECIES_ID, 1.0, Craftsmanship.Grade.EXCEPTIONAL,
		&"auto_finale", ManualPieceReceipt.Origin.AUTOMATION)
	var wrong := ManualPieceReceipt.new(&"aspen_firewood", &"quaking_aspen")
	_check(not GameState.record_earth_finale_split(automated)
		and not GameState.record_earth_finale_split(wrong),
		"automation and the wrong species cannot advance the terrestrial finale")
	var advanced := true
	for index in range(3):
		var manual := ManualPieceReceipt.new(&"lignum_vitae_firewood",
			EarthCampaign.FINAL_SPECIES_ID, 0.33, Craftsmanship.Grade.ROUGH,
			StringName("finale_%d" % index))
		advanced = advanced and GameState.record_earth_finale_split(manual)
	_check(advanced and not GameState.is_earth_master()
		and GameState.get_earth_finale_state() == GameState.EarthFinaleState.COMPLETE
		and GameState.get_earth_finale_splits() == 3,
		"three valid manual splits complete the Lignum showcase without bypassing depletion")
	_check(GameState.record_watched_automation_logs(
		GameState.get_earth_trees_remaining(), &"m11b_planetary_depletion",
		EarthCampaign.FINAL_SPECIES_ID) and GameState.is_earth_master() \
		and String(EarthCampaign.next_anti_stall_goal().kind) == "launch",
		"only exhausting the approved Earth total opens Frontier and launch")


func _test_corrupt_restore_cannot_complete() -> void:
	GameState.apply_save_dict({
		"earth_finale_state": GameState.EarthFinaleState.COMPLETE,
		"earth_finale_splits": 2,
		"earth_master": true,
	})
	_check(not GameState.is_earth_master()
		and GameState.get_earth_trees_remaining() > 0,
		"missing or corrupt additive finale fields cannot invent Earth Master status")


func _test_campaign_closure_memorial() -> void:
	GameState.apply_save_dict(_finale_ready_save(true))
	GameState.begin_earth_finale()
	for index in range(3):
		GameState.record_earth_finale_split(ManualPieceReceipt.new(
			&"lignum_vitae_firewood", EarthCampaign.FINAL_SPECIES_ID, 0.33,
			Craftsmanship.Grade.CLEAN, StringName("memorial_%d" % index)))
	GameState.record_watched_automation_logs(GameState.get_earth_trees_remaining(),
		&"m11b_memorial_depletion", EarthCampaign.FINAL_SPECIES_ID)
	var game: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var presenter: YardEquipmentPresenter = game.get_node("YardEquipment")
	_check(presenter.stage_has_landmark(&"EarthMasterMemorial")
		and presenter.get_node_or_null("YardStage/EarthMasterMemorial/LignumVitaeCrossSection") != null,
		"campaign closure permanently mounts the final cross-section in the live yard")
	var snapshot := GameState.to_save_dict()
	GameState.reset_to_defaults()
	GameState.apply_save_dict(snapshot)
	_check(GameState.is_earth_master() and GameState.get_selected_species() \
		== EarthCampaign.FINAL_SPECIES_ID,
		"Earth Master closure round-trips while leaving the save playable")
	game.queue_free()
	await get_tree().process_frame


func _finale_ready_save(include_final_species: bool) -> Dictionary:
	var owned: Array[String] = []
	var mastery: Dictionary = {}
	var projects: Array[String] = []
	for project_id: StringName in EarthCampaign.GLOBAL_PROJECT_IDS:
		projects.append(String(project_id))
	for species: SpeciesDef in SpeciesTable.all():
		if species.id == EarthCampaign.FINAL_SPECIES_ID:
			if include_final_species:
				owned.append(String(species.id))
			continue
		owned.append(String(species.id))
		var definition := M7CContent.mastery().by_species_id(species.id)
		mastery[String(species.id)] = definition.mastery_target
	return {
		"cash": 1000000000,
		"xp": (GameConfig.current().level_curve).total_xp_for_level(99),
		"owned_species": owned,
		"species_mastery_progress": mastery,
		"infrastructure_projects": projects,
	}


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)
