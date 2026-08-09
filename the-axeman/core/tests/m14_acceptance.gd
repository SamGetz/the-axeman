extends Node
## Focused M14 interplanetary timber company acceptance.

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== M14 ACCEPTANCE — Interplanetary Timber Company ===")
	_test_three_distinct_behaviors()
	_test_all_destination_progression()
	_test_fleets_charters_and_orbital_lines()
	await _test_player_visible_interplanetary_company()
	_test_v12_round_trip()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	print("=== M14 RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL M14 ACCEPTANCE CRITERIA PASS ===")
	get_tree().quit()


func _test_three_distinct_behaviors() -> void:
	var spiral := AlienCampaign.trait_by_id(&"resonant_spiralwood")
	var tide := AlienCampaign.trait_by_id(&"tideglass_timber")
	var cinder := AlienCampaign.trait_by_id(&"cinderheart_timber")
	var cinder_state: Dictionary = {}
	for _index in range(cinder.scars_to_prime):
		cinder_state = AlienCuttingBehavior.resolve_strike(cinder, cinder_state,
			false, false).state
	var primed := AlienCuttingBehavior.resolve_strike(cinder, cinder_state,
		false, false)
	_check(spiral.behavior == AlienWoodTraitDef.Behavior.RESONANT_BAND \
		and tide.behavior == AlienWoodTraitDef.Behavior.LOW_GRAVITY_FRAGMENTS \
		and tide.gravity_scale < 1.0 \
		and AlienCuttingBehavior.bounded_fragment_count(tide, 999) \
			== tide.fragment_cap \
		and cinder.behavior == AlienWoodTraitDef.Behavior.SCAR_PRIMING \
		and bool(primed.assisted) and not bool(primed.state.primed),
		"Spiralwood cues alignment, Tideglass bounds low-gravity fragments, and Cinderheart consumes one scar-primed assist")
	var economically_distinct := spiral.premium_multiplier != tide.premium_multiplier \
		and tide.premium_multiplier != cinder.premium_multiplier
	_check(economically_distinct and spiral.behavior != tide.behavior \
		and tide.behavior != cinder.behavior,
		"each alien destination changes chopping or logistics strategy rather than only price")


func _test_all_destination_progression() -> void:
	GameState.apply_save_dict(_company_ready_save())
	var now := 1000
	var all_mastered := true
	for wood_trait: AlienWoodTraitDef in AlienCampaign.traits():
		var destination := LaunchProgram.expedition_by_id(wood_trait.destination_id)
		all_mastered = all_mastered and GameState.plan_expedition(destination.id, now)
		now += destination.flight_seconds
		all_mastered = all_mastered and GameState.apply_expedition_receipt(
			GameState.resolve_expedition(now))
		all_mastered = all_mastered and AlienCampaign.quarantine(destination.id) \
			and AlienCampaign.identify(destination.id) \
			and AlienCampaign.retrieve_specimen(destination.id)
		var first := ManualPieceReceipt.new(wood_trait.yield_item, wood_trait.id,
			1.0, Craftsmanship.Grade.ROUGH,
			StringName("%s_certification" % wood_trait.id))
		all_mastered = all_mastered and GameState.record_alien_manual_completion(first) \
			and AlienCampaign.unlock_repeat_cargo(destination.id)
		for index in range(1, wood_trait.manual_mastery_target):
			all_mastered = all_mastered and GameState.record_alien_manual_completion(
				ManualPieceReceipt.new(wood_trait.yield_item, wood_trait.id, 1.0,
					Craftsmanship.Grade.CLEAN,
					StringName("%s_mastery_%d" % [wood_trait.id, index])))
		all_mastered = all_mastered and GameState.get_alien_destination_state(
			destination.id) == GameState.AlienDestinationState.MASTERED
	_check(all_mastered,
		"all three destinations complete survey → specimen → manual certification → repeat cargo → mastery")


func _test_fleets_charters_and_orbital_lines() -> void:
	var built := true
	for wood_trait: AlienWoodTraitDef in AlienCampaign.traits():
		built = built and GameState.commission_cargo_fleet(wood_trait.destination_id) \
			and GameState.build_orbital_line(wood_trait.destination_id)
	_check(built,
		"certified mastered destinations add bounded cargo fleets and alien-only orbital cutting lines")
	var mastery_before: Dictionary = {}
	for wood_trait: AlienWoodTraitDef in AlienCampaign.traits():
		mastery_before[wood_trait.id] = GameState.get_alien_manual_mastery(wood_trait.id)
	var state_before := GameState.to_save_dict()
	_check(GameState.set_expedition_charter(&"tidal_moon")
		and GameState.set_expedition_charter(&"ember_world") \
		and GameState.get_expedition_charter() == &"ember_world" \
		and GameState.get_cargo_fleet_count(&"tidal_moon") == 1,
		"soft charters freely reprioritize logistics without resetting fleets or history")
	var receipt := AlienCompanySimulation.simulate(
		GameState.get_alien_company_simulation_input(), 60)
	var automated_before := GameState.get_automated_log_equivalents()
	_check(receipt.total_logs() > 0 and receipt.processed_logs.size() == 3 \
		and AlienCampaign.apply_automation_receipt(receipt) \
		and not AlienCampaign.apply_automation_receipt(receipt) \
		and GameState.get_automated_log_equivalents() \
			== automated_before + receipt.total_logs(),
		"certified orbital lines produce one bounded idempotent company receipt across all destinations")
	var mastery_unchanged := true
	for species_id: StringName in mastery_before:
		mastery_unchanged = mastery_unchanged and GameState.get_alien_manual_mastery(
			species_id) == int(mastery_before[species_id])
	_check(mastery_unchanged and (state_before.get("alien_destination_states") as Dictionary) \
		== (GameState.to_save_dict().get("alien_destination_states") as Dictionary),
		"orbital automation cannot certify a new specimen or earn manual alien mastery")


func _test_player_visible_interplanetary_company() -> void:
	var game: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var presenter: YardEquipmentPresenter = game.get_node("YardEquipment")
	_check(presenter.stage_has_landmark(&"HeadquartersOffice") \
		and presenter.stage_has_landmark(&"EarthMasterMemorial") \
		and presenter.stage_has_landmark(&"OrbitalSpecimenRig") \
		and presenter.stage_has_landmark(&"CargoFleetPad"),
		"completed Earth headquarters remains visible beside the specimen rig and bounded fleet pad")
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	hud.get_node("QuickMenu/AtlasButton").pressed.emit()
	await get_tree().process_frame
	var launch_card: VBoxContainer = hud.get_node(
		"AtlasPanel/Column/Scroll/List/LaunchProgramme")
	_check(launch_card.get_node_or_null("kepler_grove") != null \
		and launch_card.get_node_or_null("tidal_moon") != null \
		and launch_card.get_node_or_null("ember_world") != null,
		"the live company panel retains all three authored destinations and their actions")
	hud.queue_free()
	game.queue_free()
	await get_tree().process_frame


func _test_v12_round_trip() -> void:
	var snapshot := GameState.to_save_dict()
	GameState.reset_to_defaults()
	GameState.apply_save_dict(snapshot)
	var restored := true
	for wood_trait: AlienWoodTraitDef in AlienCampaign.traits():
		restored = restored and GameState.get_alien_destination_state(
			wood_trait.destination_id) == GameState.AlienDestinationState.MASTERED \
			and GameState.get_cargo_fleet_count(wood_trait.destination_id) == 1 \
			and GameState.has_orbital_line(wood_trait.destination_id)
	_check(restored and GameState.is_earth_master(),
		"save v14 preserves the repeatable three-destination company and completed Earth headquarters")


func _company_ready_save() -> Dictionary:
	return {
		"cash": 30000000000,
		"building_tiers": {"headquarters_yard": 2},
		"infrastructure_projects": ["headquarters_yard"],
		"earth_finale_state": GameState.EarthFinaleState.COMPLETE,
		"earth_finale_splits": 3,
		"earth_master": true,
		"launch_projects": ["mission_control", "gantry", "orbital_test",
			"deep_space_vessel"],
		"spacecraft_loadout": {0: "frontier_drive", 1: "timber_hold",
			2: "deep_space_shield"},
	}


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)
