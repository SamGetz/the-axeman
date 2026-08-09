extends Node
## Focused M13 first alien timber expedition acceptance.

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== M13 ACCEPTANCE — First Alien Timber Expedition ===")
	_test_kepler_protocol()
	_test_manual_certification_unlocks()
	_test_resonant_behavior_contract()
	await _test_live_spiralwood_and_specimen_rig()
	_test_v12_migration_restore()
	GameState.reset_to_defaults()
	print("=== M13 RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL M13 ACCEPTANCE CRITERIA PASS ===")
	get_tree().quit()


func _test_kepler_protocol() -> void:
	GameState.apply_save_dict(_flight_ready_save())
	_check(AlienCampaign.validate_catalogue().is_empty()
		and AlienCampaign.traits().size() == 3,
		"the alien wood and bounded company catalogues validate")
	_check(GameState.plan_expedition(&"kepler_grove", 100)
		and GameState.apply_expedition_receipt(GameState.resolve_expedition(220)),
		"the first fixed-time Kepler Grove expedition returns one unapplied arrival receipt")
	_check(GameState.get_alien_destination_state(&"kepler_grove") \
		== GameState.AlienDestinationState.SURVEYED \
		and AlienCampaign.quarantine(&"kepler_grove") \
		and AlienCampaign.identify(&"kepler_grove") \
		and AlienCampaign.retrieve_specimen(&"kepler_grove"),
		"survey, quarantine, identification and specimen delivery advance visibly in order")
	_check(GameState.owns_species(&"resonant_spiralwood") \
		and GameState.select_species(&"resonant_spiralwood"),
		"the delivered first specimen becomes manually selectable on the home-yard block")


func _test_manual_certification_unlocks() -> void:
	var automated := ManualPieceReceipt.new(&"spiralwood_firewood",
		&"resonant_spiralwood", 1.0, Craftsmanship.Grade.EXCEPTIONAL,
		&"auto_spiral", ManualPieceReceipt.Origin.AUTOMATION)
	var manual := ManualPieceReceipt.new(&"spiralwood_firewood",
		&"resonant_spiralwood", 1.0, Craftsmanship.Grade.ROUGH, &"manual_spiral")
	_check(not GameState.record_alien_manual_completion(automated)
		and GameState.record_alien_manual_completion(manual)
		and not GameState.record_alien_manual_completion(manual),
		"only one traceable manual specimen completion can certify Spiralwood")
	_check(AlienCampaign.alien_cutting_profile_unlocked(&"resonant_spiralwood") \
		and not AlienCampaign.premium_order_family(&"kepler_grove").is_empty()
		and GameState.configure_spacecraft(&"resonance_dampener"),
		"manual certification unlocks the alien profile, premium family and resonance upgrade")
	_check(AlienCampaign.unlock_repeat_cargo(&"kepler_grove"),
		"repeat cargo unlocks only after the manual certification presentation")


func _test_resonant_behavior_contract() -> void:
	var wood_trait := AlienCampaign.trait_by_id(&"resonant_spiralwood")
	var failed := AlienCuttingBehavior.resolve_strike(wood_trait, {}, false, false)
	var missed := AlienCuttingBehavior.resolve_strike(wood_trait, failed.state,
		false, false)
	var aligned := AlienCuttingBehavior.resolve_strike(wood_trait, missed.state,
		false, true)
	_check(bool(failed.reveal_cue) and not bool(missed.assisted) \
		and bool(aligned.assisted) and int(aligned.state.band_serial) == 1,
		"a failed strike reveals a weak band and only the next aligned strike receives the bounded assist")


func _test_live_spiralwood_and_specimen_rig() -> void:
	var game: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	game.auto_sell = false
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	game.debug_split_roll = 0
	var failed: bool = game.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	_check(not failed and game.debug_has_alien_weak_band(),
		"an unsuccessful live Spiralwood strike paints a luminous weak band on the familiar stump")
	var assisted: bool = game.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	_check(assisted,
		"the next valid live strike on the revealed band guarantees one assisted MeshSlicer split")
	var presenter: YardEquipmentPresenter = game.get_node("YardEquipment")
	_check(presenter.stage_has_landmark(&"OrbitalSpecimenRig"),
		"the familiar chopping block visibly evolves into the bounded specimen rig")
	game.queue_free()
	await get_tree().process_frame


func _test_v12_migration_restore() -> void:
	var migrated := SaveSystem._migrate({"arrived_destinations": ["kepler_grove"]}, 11)
	_check((migrated.get("alien_destination_states") as Dictionary).is_empty()
		and (migrated.get("alien_manual_mastery") as Dictionary).is_empty()
		and (migrated.get("cargo_fleets") as Dictionary).is_empty(),
		"v11 to v12 migration invents no identification, certification, mastery or fleet")
	var snapshot := GameState.to_save_dict()
	GameState.reset_to_defaults()
	GameState.apply_save_dict(snapshot)
	_check(GameState.get_alien_destination_state(&"kepler_grove") \
		== GameState.AlienDestinationState.REPEAT_CARGO \
		and GameState.get_alien_manual_mastery(&"resonant_spiralwood") == 1,
		"first-contact state and manual certification round-trip without replaying rewards")


func _flight_ready_save() -> Dictionary:
	return {
		"cash": 10000000000,
		"earth_finale_state": GameState.EarthFinaleState.COMPLETE,
		"earth_finale_splits": 3,
		"earth_master": true,
		"launch_projects": ["mission_control", "gantry", "orbital_test",
			"deep_space_vessel"],
		"spacecraft_loadout": {0: "frontier_drive", 1: "specimen_cradle",
			2: "deep_space_shield"},
	}


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)
