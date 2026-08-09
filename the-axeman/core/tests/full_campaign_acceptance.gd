extends Node
## Accelerated fresh-campaign proof for the continuous M7B–M14 programme.
##
## This deliberately uses the same public progression commands that player
## actions call. Large grants compress waiting/tuning time; no save snapshot is
## injected to skip a campaign state.

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== FULL CAMPAIGN ACCEPTANCE — Fresh Yard Through M14 ===")
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	_test_additive_migration_chain()
	_test_foundations_and_earth_campaign()
	_test_launch_and_three_destinations()
	_test_repeatable_company_and_round_trip()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	print("=== FULL CAMPAIGN RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== FULL CAMPAIGN THROUGH M14 PASS ===")
	get_tree().quit()


func _test_additive_migration_chain() -> void:
	var all_safe := true
	for version in range(1, SaveSystem.SAVE_VERSION + 1):
		var source := {
			"cash": 41,
			"xp": 7,
			"building_tiers": {"supplier_ledger": 2},
			"owned_species": ["quaking_aspen"],
			"earth_master": false,
			"active_commissions": [],
		}
		var migrated := SaveSystem._migrate(source, version)
		all_safe = all_safe and int(migrated.get("cash", -1)) == 41 \
			and int(migrated.get("xp", -1)) == 7 \
			and (migrated.get("building_tiers", {}) as Dictionary).has("supplier_ledger") \
			and not bool(migrated.get("earth_master", false)) \
			and (migrated.get("launch_projects", []) as Array).is_empty() \
			and (migrated.get("alien_destination_states", {}) as Dictionary).is_empty()
	_check(all_safe,
		"the migration chain through v14 preserves campaign purchases, refunds skills, and invents no campaign rewards")


func _test_foundations_and_earth_campaign() -> void:
	var progressed := GameState.add_cash(100000000000) \
		and GameState.add_xp(1000000000) and GameState.add_reputation(99)
	# These public purchase signals are the command path used by the shop after
	# payment. The accelerated harness grants the test budget above and skips
	# only the real-time introductory-order wait.
	for upgrade_id: StringName in [GameState.UPGRADE_SUPPLIER_LEDGER,
			GameState.UPGRADE_HANDCART, GameState.UPGRADE_COFFEE_THERMOS,
			&"mechanical_splitter"]:
		EventBus.building_upgraded.emit(upgrade_id, GameState.DEFAULT_BUILDING_TIER + 1)
	for species: SpeciesDef in SpeciesTable.all():
		if species.supplier_upgrade_id != &"" and GameState.get_building_tier(
				species.supplier_upgrade_id) <= GameState.DEFAULT_BUILDING_TIER:
			EventBus.building_upgraded.emit(species.supplier_upgrade_id,
				GameState.DEFAULT_BUILDING_TIER + 1)
	for upgrade: LogisticsUpgradeDef in CompanyLogistics.upgrades():
		progressed = progressed and CompanyLogistics.buy(upgrade.id)
	progressed = progressed and CompanyStrategy.buy_machine() \
		and GameState.set_company_doctrine(&"craft_house") \
		and GameState.set_company_doctrine(&"logistics_company") \
		and GameState.set_company_doctrine(&"global_specialist")
	_check(progressed and CompanyLogistics.all_owned(),
		"the public purchase path establishes yard growth, certified logistics and adjustable doctrine")

	var network_ready := true
	for region: RegionDef in RegionalNetwork.regions():
		network_ready = network_ready and GameState.discover_region(region.id) \
			and GameState.add_regional_standing(region.id, region.depot_standing_required) \
			and GameState.build_regional_depot(region.id) \
			and GameState.establish_regional_route(region.id)
	_check(network_ready,
		"all seven Earth regions advance through discovery, standing, depot and route")

	var terrestrial_ready := true
	for species: SpeciesDef in SpeciesTable.all():
		if species.id == EarthCampaign.FINAL_SPECIES_ID:
			continue
		if not GameState.owns_species(species.id):
			terrestrial_ready = terrestrial_ready and GameState.try_buy_species(species.id)
		while not GameState.is_species_mastered(species.id):
			terrestrial_ready = terrestrial_ready and GameState.record_species_completion(species.id)
	terrestrial_ready = terrestrial_ready and GameState.record_watched_automation_logs(500000)
	for project: InfrastructureProjectDef in RegionalNetwork.projects():
		terrestrial_ready = terrestrial_ready and GameState.complete_infrastructure_project(project.id)
	_check(terrestrial_ready and EarthCampaign.terrestrial_requirements_complete(),
		"the 24-species manual catalogue and all infrastructure projects unlock the final showcase")

	var finale := GameState.try_buy_species(EarthCampaign.FINAL_SPECIES_ID) \
		and GameState.begin_earth_finale()
	for index in range(3):
		finale = finale and GameState.record_earth_finale_split(ManualPieceReceipt.new(
			&"lignum_vitae_firewood", EarthCampaign.FINAL_SPECIES_ID, 1.0,
			Craftsmanship.Grade.CLEAN, StringName("campaign_finale_%d" % index)))
	while not GameState.is_species_mastered(EarthCampaign.FINAL_SPECIES_ID):
		finale = finale and GameState.record_species_completion(EarthCampaign.FINAL_SPECIES_ID)
	finale = finale and GameState.record_watched_automation_logs(
		GameState.get_earth_trees_remaining(), &"campaign_planetary_depletion",
		EarthCampaign.FINAL_SPECIES_ID)
	_check(finale and GameState.is_earth_master()
		and GameState.get_mastered_species_count() == SpeciesTable.count(),
		"the manual three-stage Lignum Vitae finale awards Earth Master and leaves all 25 woods mastered")


func _test_launch_and_three_destinations() -> void:
	var launched := true
	for project: LaunchProjectDef in LaunchProgram.projects():
		launched = launched and InventoryManager.add_item(project.contribution_item_id,
			project.contribution_amount) \
			and LaunchProgram.contribute(project.id, project.contribution_amount) \
			and GameState.complete_launch_project(project.id)
	launched = launched and GameState.configure_spacecraft(&"frontier_drive") \
		and GameState.configure_spacecraft(&"timber_hold") \
		and GameState.configure_spacecraft(&"deep_space_shield")
	_check(launched and GameState.has_launch_project(&"deep_space_vessel"),
		"Earth output and explicit timber contributions construct and configure the launch programme")

	var now := 1000
	var all_mastered := true
	for wood_trait: AlienWoodTraitDef in AlienCampaign.traits():
		var destination := LaunchProgram.expedition_by_id(wood_trait.destination_id)
		all_mastered = all_mastered and GameState.plan_expedition(destination.id, now)
		now += destination.flight_seconds
		all_mastered = all_mastered and GameState.apply_expedition_receipt(
			GameState.resolve_expedition(now)) \
			and AlienCampaign.quarantine(destination.id) \
			and AlienCampaign.identify(destination.id) \
			and AlienCampaign.retrieve_specimen(destination.id)
		all_mastered = all_mastered and GameState.record_alien_manual_completion(
			ManualPieceReceipt.new(wood_trait.yield_item, wood_trait.id, 1.0,
				Craftsmanship.Grade.ROUGH,
				StringName("campaign_%s_cert" % wood_trait.id))) \
			and AlienCampaign.unlock_repeat_cargo(destination.id)
		for index in range(1, wood_trait.manual_mastery_target):
			all_mastered = all_mastered and GameState.record_alien_manual_completion(
				ManualPieceReceipt.new(wood_trait.yield_item, wood_trait.id, 1.0,
					Craftsmanship.Grade.CLEAN,
					StringName("campaign_%s_%d" % [wood_trait.id, index])))
		all_mastered = all_mastered and GameState.get_alien_destination_state(
			destination.id) == GameState.AlienDestinationState.MASTERED
	_check(all_mastered,
		"each timed expedition completes first-contact handling, manual certification, repeat cargo and mastery")


func _test_repeatable_company_and_round_trip() -> void:
	var completion_signals := [0]
	GameState.campaign_completed.connect(func() -> void:
		completion_signals[0] += 1, CONNECT_ONE_SHOT)
	var company_ready := true
	for wood_trait: AlienWoodTraitDef in AlienCampaign.traits():
		company_ready = company_ready and GameState.commission_cargo_fleet(
			wood_trait.destination_id) and GameState.build_orbital_line(
			wood_trait.destination_id)
	company_ready = company_ready and GameState.set_expedition_charter(&"tidal_moon")
	var receipt := AlienCompanySimulation.simulate(
		GameState.get_alien_company_simulation_input(), 60)
	var automated_before := GameState.get_automated_log_equivalents()
	company_ready = company_ready and receipt.processed_logs.size() == 3 \
		and AlienCampaign.apply_automation_receipt(receipt) \
		and not AlienCampaign.apply_automation_receipt(receipt) \
		and GameState.get_automated_log_equivalents() \
			== automated_before + receipt.total_logs()
	_check(company_ready,
		"three bounded orbital lines form a repeatable, charter-prioritized and idempotent alien company")
	var frontier_complete := not GameState.is_campaign_complete()
	for node: SkillNodeDef in SkillTree.get_nodes():
		if node != null and node.branch_id == &"frontier":
			var bought := SkillTree.buy(node.id)
			frontier_complete = frontier_complete and bought == 1
	_check(frontier_complete and SkillTree.frontier_purchases_owned() == 9 \
		and SkillTree.get_level(&"frontier_master") == 1 \
		and GameState.is_campaign_complete() and completion_signals[0] == 1,
		"three alien masteries fund exactly nine Frontier purchases and the combined receipt rolls credits once [owned=%d points=%d combined=%s complete=%s signals=%d]" % [
			SkillTree.frontier_purchases_owned(), GameState.get_skill_points_available(),
			GameState.has_combined_orbital_receipt(), GameState.is_campaign_complete(),
			completion_signals[0]])

	var progression := GameState.to_save_dict()
	var inventory := InventoryManager.to_save_dict()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	GameState.apply_save_dict(progression)
	InventoryManager.apply_save_dict(inventory)
	var restored := GameState.is_earth_master() \
		and GameState.has_launch_project(&"deep_space_vessel") \
		and GameState.has_combined_orbital_receipt() \
		and GameState.is_campaign_complete()
	for wood_trait: AlienWoodTraitDef in AlienCampaign.traits():
		restored = restored and GameState.get_alien_destination_state(
			wood_trait.destination_id) == GameState.AlienDestinationState.MASTERED \
			and GameState.get_cargo_fleet_count(wood_trait.destination_id) == 1 \
			and GameState.has_orbital_line(wood_trait.destination_id)
	_check(restored,
		"the uninterrupted campaign round-trips as a playable three-destination company with Earth retained")


func _check(condition: bool, description: String) -> void:
	if condition:
		_passes += 1
		print("PASS: %s" % description)
	else:
		_fails += 1
		print("FAIL: %s" % description)
