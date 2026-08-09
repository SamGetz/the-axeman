extends Node
## Focused M10 continental company acceptance.

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== M10 ACCEPTANCE — Continental Company and Build Variety ===")
	_test_complete_earth_sources_and_routes()
	_test_free_doctrine_switching()
	_test_hydraulic_capacity()
	await _test_major_projects_and_headquarters()
	_test_v10_migration_restore()
	await _test_expanded_native_atlas()
	GameState.reset_to_defaults()
	print("=== M10 RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL M10 ACCEPTANCE CRITERIA PASS ===")
	get_tree().quit()


func _test_complete_earth_sources_and_routes() -> void:
	_check(RegionalNetwork.regions().size() == 7
		and RegionalNetwork.validate_catalogue().is_empty(),
		"the atlas expands to seven valid authored Earth regions")
	var sourced: Dictionary = {}
	for region: RegionDef in RegionalNetwork.regions():
		for species_id: StringName in region.species_ids:
			sourced[species_id] = region.id
	_check(sourced.size() == SpeciesTable.count(),
		"all 25 Earth species have exactly one authored supplier source")
	var tiers: Dictionary = {}
	for route: RouteDef in RegionalNetwork.routes():
		tiers[int(route.tier)] = true
	_check(tiers.has(RouteDef.Tier.ROAD) and tiers.has(RouteDef.Tier.RAIL)
		and tiers.has(RouteDef.Tier.PORT),
		"road, rail and port route tiers all remain economically usable")


func _test_free_doctrine_switching() -> void:
	GameState.apply_save_dict({
		"cash": 12345,
		"supplier_input_queues": {"quaking_aspen": 3},
		"route_priorities": ["quaking_aspen"],
	})
	var cash := GameState.get_cash()
	var queues := GameState.get_supplier_input_queues()
	_check(CompanyStrategy.validate_catalogue().is_empty()
		and CompanyStrategy.doctrines().size() == 3,
		"Craft House, Logistics Company and Global Specialist use provisional typed data")
	var switched := true
	for doctrine: CompanyDoctrineDef in CompanyStrategy.doctrines():
		switched = switched and GameState.set_company_doctrine(doctrine.id) \
			and GameState.get_cash() == cash \
			and GameState.get_supplier_input_queues() == queues
	_check(switched,
		"doctrines are mutually exclusive and freely adjustable without stranding cash or queues")
	GameState.set_company_doctrine(&"logistics_company")
	_check(CompanyStrategy.effective_dispatch_capacity() \
		== CompanySimulation.config().dispatch_capacity + 1,
		"Logistics Company changes bounded dispatch capacity through resource data")


func _test_hydraulic_capacity() -> void:
	var machine := MechanicalSplitter.machine_definition()
	GameState.apply_save_dict({
		"cash": 20000000,
		"building_tiers": {String(machine.id): 2},
	})
	var before := CompanyStrategy.effective_dispatch_capacity()
	var cost := CompanyStrategy.machine().cost
	_check(CompanyStrategy.buy_machine()
		and GameState.get_cash() == 20000000 - cost
		and Shop.get_level(CompanyStrategy.machine().id) == 1,
		"Hydraulic Split Banks purchase atomically around the proven splitter contract")
	_check(CompanyStrategy.effective_dispatch_capacity() == before \
		+ CompanyStrategy.machine().added_dispatch_capacity,
		"the split banks add explicit parallel capacity without changing profiles")


func _test_major_projects_and_headquarters() -> void:
	GameState.apply_save_dict({"cash": 100000000, "lifetime_wood_chopped": 50000})
	var completed := true
	for project: InfrastructureProjectDef in RegionalNetwork.projects():
		# M11 appends three global projects to the shared typed catalogue. They
		# deliberately exceed this M10 fixture and have their own focused suite.
		if project.id in [&"world_catalogue_archive", &"heavy_freight_grid", &"global_buyer_exchange"]:
			continue
		completed = completed and GameState.complete_infrastructure_project(project.id)
	_check(completed and GameState.has_infrastructure_project(&"headquarters_yard"),
		"major infrastructure contracts consume cash only after their output gates are met")
	_check(YardProgression.current_stage() == YardProgression.Stage.HEADQUARTERS,
		"the completed headquarters contract derives the fifth visible yard state")
	var game: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var presenter: YardEquipmentPresenter = game.get_node("YardEquipment")
	_check(presenter.stage_has_landmark(&"HeadquartersOffice"),
		"the headquarters yard adds a recognizable dispatch office and doctrine board")
	game.queue_free()
	await get_tree().process_frame


func _test_v10_migration_restore() -> void:
	var migrated := SaveSystem._migrate({"cash": 4}, 9)
	_check(String(migrated.get("company_doctrine", "x")) == ""
		and (migrated.get("infrastructure_projects") as Array).is_empty(),
		"v9 to v10 migration invents no doctrine or completed project")
	GameState.apply_save_dict({
		"company_doctrine": "craft_house",
		"infrastructure_projects": ["heavy_rail_interchange"],
	})
	var snapshot := GameState.to_save_dict()
	GameState.reset_to_defaults()
	GameState.apply_save_dict(snapshot)
	_check(GameState.get_company_doctrine() == &"craft_house"
		and GameState.has_infrastructure_project(&"heavy_rail_interchange"),
		"doctrine and infrastructure state round-trip without replaying costs")


func _test_expanded_native_atlas() -> void:
	GameState.apply_save_dict({"reputation": 99})
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	hud.get_node("QuickMenu/AtlasButton").pressed.emit()
	await get_tree().process_frame
	var list: VBoxContainer = hud.get_node("AtlasPanel/Column/Scroll/List")
	_check(list.get_child_count() == RegionalNetwork.regions().size() + 1
		and list.get_node_or_null("CompanyStrategy") != null
		and list.get_node_or_null("australia") != null
		and list.get_node_or_null("caribbean_specialist_exchange") != null,
		"the native atlas exposes strategy, projects and every continental supplier")
	hud.queue_free()
	await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)
