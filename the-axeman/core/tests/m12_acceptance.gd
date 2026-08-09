extends Node
## Focused M12 launch programme acceptance.

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== M12 ACCEPTANCE — Launch Programme ===")
	_test_typed_programme_and_frontier_branch()
	_test_staged_construction()
	_test_configurable_vessel_and_fixed_flight()
	_test_v11_migration_restore()
	await _test_visible_space_yard_and_ui()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	print("=== M12 RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL M12 ACCEPTANCE CRITERIA PASS ===")
	get_tree().quit()


func _test_typed_programme_and_frontier_branch() -> void:
	_check(LaunchProgram.validate_catalogues().is_empty()
		and LaunchProgram.projects().size() == 4
		and LaunchProgram.components().size() == 7,
		"four staged projects, configurable components and expedition definitions validate")
	var frontier := M7CContent.branches().by_id(&"frontier")
	var frontier_nodes := 0
	for node: SkillNodeDef in SkillTree.get_nodes():
		if node.branch_id == &"frontier":
			frontier_nodes += 1
	_check(frontier != null and frontier_nodes == 9 \
		and frontier.reveal_gate == SkillBranchDef.RevealGate.EARTH_MASTER \
		and M7CContent.validate_all().is_empty(),
		"the nine-node Earth-Master Frontier branch adds handling and preparation without invalidating the skill tree")


func _test_staged_construction() -> void:
	GameState.apply_save_dict(_earth_master_save())
	var inventory: Dictionary = {}
	for project: LaunchProjectDef in LaunchProgram.projects():
		inventory[String(project.contribution_item_id)] = project.contribution_amount
	InventoryManager.apply_save_dict(inventory)
	var staged := true
	for project: LaunchProjectDef in LaunchProgram.projects():
		staged = staged and LaunchProgram.contribute(project.id,
			project.contribution_amount)
		staged = staged and GameState.complete_launch_project(project.id)
	_check(staged and GameState.has_launch_project(&"mission_control") \
		and GameState.has_launch_project(&"gantry") \
		and GameState.has_launch_project(&"orbital_test") \
		and GameState.has_launch_project(&"deep_space_vessel"),
		"Mission Control, Gantry, Orbital Test and Deep-Space Vessel complete in authored order")
	var inventory_empty := true
	for project: LaunchProjectDef in LaunchProgram.projects():
		inventory_empty = inventory_empty and InventoryManager.get_count(
			project.contribution_item_id) == 0
	_check(inventory_empty,
		"explicit timber contributions pass atomically through InventoryManager without a space currency")


func _test_configurable_vessel_and_fixed_flight() -> void:
	var range := LaunchProgram.component_by_id(&"survey_drive")
	var cargo := LaunchProgram.component_by_id(&"specimen_cradle")
	var shield := LaunchProgram.component_by_id(&"quarantine_shield")
	_check(GameState.configure_spacecraft(range.id)
		and GameState.configure_spacecraft(cargo.id)
		and GameState.configure_spacecraft(shield.id),
		"range, cargo and shielding slots can be configured after vessel construction")
	var departure := 1000
	var destination := LaunchProgram.expedition_by_id(&"kepler_grove")
	_check(GameState.plan_expedition(destination.id, departure),
		"an eligible craft can depart for Kepler Grove with an injected clock")
	var original := GameState.get_active_expedition()
	GameState.record_manual_log_equivalent(&"construction_after_departure")
	GameState.record_watched_automation_logs(1000000)
	var after_output := GameState.get_active_expedition()
	_check(int(original.arrives_at) == departure + destination.flight_seconds \
		and original == after_output \
		and GameState.resolve_expedition(int(original.arrives_at) - 1) == null,
		"company output may help unstarted construction but never shortens elapsed flight time")
	var receipt := GameState.resolve_expedition(int(original.arrives_at))
	_check(receipt != null and GameState.apply_expedition_receipt(receipt)
		and not GameState.apply_expedition_receipt(receipt)
		and GameState.has_arrived_at(destination.id),
		"arrival is an unapplied, idempotent receipt with no premium acceleration path")


func _test_v11_migration_restore() -> void:
	var migrated := SaveSystem._migrate({"earth_master": true}, 10)
	_check((migrated.get("launch_projects") as Array).is_empty()
		and (migrated.get("active_expedition") as Dictionary).is_empty()
		and (migrated.get("spacecraft_loadout") as Dictionary).is_empty(),
		"v10 to v11 migration invents no launch construction, craft or flight")
	var snapshot := GameState.to_save_dict()
	GameState.reset_to_defaults()
	GameState.apply_save_dict(snapshot)
	_check(GameState.has_launch_project(&"deep_space_vessel")
		and GameState.has_arrived_at(&"kepler_grove")
		and GameState.get_spacecraft_capability(SpacecraftComponentDef.Slot.RANGE) == 2,
		"completed construction, vessel loadout and arrived destinations round-trip")


func _test_visible_space_yard_and_ui() -> void:
	var game: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var presenter: YardEquipmentPresenter = game.get_node("YardEquipment")
	_check(presenter.stage_has_landmark(&"MissionControl") \
		and presenter.stage_has_landmark(&"LaunchGantry") \
		and presenter.stage_has_landmark(&"DeepSpaceVessel"),
		"Mission Control, the gantry and configurable vessel are recognizable native yard landmarks")
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	hud.get_node("QuickMenu/AtlasButton").pressed.emit()
	await get_tree().process_frame
	_check(hud.get_node_or_null("AtlasPanel/Column/Scroll/List/LaunchProgramme") != null,
		"the supplier atlas exposes the player-visible launch programme and vessel controls")
	hud.queue_free()
	game.queue_free()
	await get_tree().process_frame


func _earth_master_save() -> Dictionary:
	var owned: Array[String] = []
	var mastery: Dictionary = {}
	for species: SpeciesDef in SpeciesTable.all():
		owned.append(String(species.id))
		mastery[String(species.id)] = M7CContent.mastery().by_species_id(
			species.id).mastery_target
	return {
		"cash": 5000000000,
		"owned_species": owned,
		"species_mastery_progress": mastery,
		"manual_log_equivalents": 500000,
		"earth_finale_state": GameState.EarthFinaleState.COMPLETE,
		"earth_finale_splits": 3,
		"earth_master": true,
	}


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)
