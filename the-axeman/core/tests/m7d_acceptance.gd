extends Node
## Focused M7D acceptance for derived, visibly distinct yard growth.

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== M7D ACCEPTANCE — Visible Yard Progression ===")
	_check(YardProgression.validate_catalogue().is_empty(),
		"four labelled authored yard-stage resources validate")
	_test_derived_states()
	await _test_native_landmarks_and_bounded_vehicle()
	GameState.reset_to_defaults()
	print("=== M7D RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL M7D ACCEPTANCE CRITERIA PASS ===")
	get_tree().quit()


func _test_derived_states() -> void:
	GameState.reset_to_defaults()
	_check(YardProgression.current_stage() == YardProgression.Stage.STUMP,
		"a fresh campaign derives the recognizable stump clearing")
	GameState.apply_save_dict({"building_tiers": {
		String(GameState.UPGRADE_SUPPLIER_LEDGER): 2,
	}})
	_check(YardProgression.current_stage() == YardProgression.Stage.SHED,
		"the existing Supplier Ledger purchase derives the supplier shed")
	GameState.apply_save_dict({"building_tiers": {
		String(GameState.UPGRADE_HANDCART): 2,
	}})
	_check(YardProgression.current_stage() == YardProgression.Stage.WORKING_YARD,
		"the existing Handcart purchase derives the working yard")
	var machine := MechanicalSplitter.machine_definition()
	GameState.apply_save_dict({"building_tiers": {String(machine.id): 2}})
	_check(YardProgression.current_stage() == YardProgression.Stage.DEPOT,
		"the certified Mechanical Splitter installation derives the depot")
	_check(not GameState.to_save_dict().has("yard_stage")
		and not GameState.to_save_dict().has("cosmetic_yard_tier"),
		"no duplicate cosmetic yard tier is persisted")


func _test_native_landmarks_and_bounded_vehicle() -> void:
	var machine := MechanicalSplitter.machine_definition()
	var cases := [
		{"tiers": {}, "stage": YardProgression.Stage.STUMP,
			"landmark": &"StageSign"},
		{"tiers": {String(GameState.UPGRADE_SUPPLIER_LEDGER): 2},
			"stage": YardProgression.Stage.SHED, "landmark": &"SupplierShed"},
		{"tiers": {String(GameState.UPGRADE_HANDCART): 2},
			"stage": YardProgression.Stage.WORKING_YARD, "landmark": &"ContractStaging"},
		{"tiers": {String(machine.id): 2}, "stage": YardProgression.Stage.DEPOT,
			"landmark": &"DepotLoadingBay"},
	]
	for case: Dictionary in cases:
		GameState.apply_save_dict({"building_tiers": case.tiers})
		var game: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
		add_child(game)
		await get_tree().process_frame
		await get_tree().process_frame
		var presenter: YardEquipmentPresenter = game.get_node("YardEquipment")
		_check(presenter.visible_yard_stage() == int(case.stage)
			and presenter.stage_has_landmark(case.landmark),
			"%s renders its native identifying landmark" % YardProgression.definition(case.stage).display_name)
		if int(case.stage) == YardProgression.Stage.WORKING_YARD:
			_check(presenter.stage_has_landmark(&"ContractStaging")
				and presenter.get_node_or_null("YardStage/ContractStaging/TrophyCrossSections") != null,
				"the working yard shows contract crates, delivery staging and trophy cross-sections")
		if int(case.stage) == YardProgression.Stage.DEPOT:
			var count_before := presenter.get_node("YardStage").get_child_count()
			for _frame in range(30):
				await get_tree().process_frame
			var vehicle: Node3D = presenter.get_node("YardStage/DepotLoadingBay/YardVehicle")
			_check(absf(vehicle.position.x) <= 1.29
				and presenter.get_node("YardStage").get_child_count() == count_before,
				"the depot vehicle arrives/departs inside fixed bounds with no node growth")
		game.queue_free()
		await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)
