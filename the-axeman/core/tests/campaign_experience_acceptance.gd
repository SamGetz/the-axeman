extends Node
## Cross-system acceptance for the four-hour experience pass. It exercises the
## compact commission flow, phase-derived objective spine, handling families,
## phased skill presentation and credits shell without bypassing their writers.

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== CAMPAIGN EXPERIENCE ACCEPTANCE ===")
	_test_handling_profiles_and_mastery_shape()
	_test_campaign_phase_spine()
	_test_standing_commission_loop()
	await _test_hud_focus_and_credits()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	print("=== CAMPAIGN EXPERIENCE RESULT: %d passed, %d failed ===" % [
		_passes, _fails])
	if _fails == 0:
		print("=== FOUR-HOUR EXPERIENCE CONTRACT PASS ===")
	get_tree().quit(1 if _fails > 0 else 0)


func _test_handling_profiles_and_mastery_shape() -> void:
	var profiles := WoodHandlingProfiles.all()
	var signatures: Dictionary = {}
	for profile: WoodHandlingProfileDef in profiles:
		signatures["%.3f|%.3f|%.3f" % [profile.fresh_split_modifier,
			profile.scar_bonus_multiplier, profile.size_relief_multiplier]] = true
	_check(WoodHandlingProfiles.validate_catalogue().is_empty() \
		and profiles.size() == 5 and signatures.size() == 5,
		"five distinct handling families cover the full terrestrial catalogue")
	var total_logs := 0
	var targets: Dictionary = {}
	for species: SpeciesDef in SpeciesTable.all():
		var definition := M7CContent.mastery().by_species_id(species.id)
		total_logs += definition.mastery_target
		targets[definition.mastery_target] = true
	_check(SpeciesTable.count() == 25 and total_logs == 155 \
		and targets.keys().duplicate().size() == 3 \
		and targets.has(5) and targets.has(6) and targets.has(7),
		"all 25 Earth woods require manual mastery without a late 80-log wall")


func _test_campaign_phase_spine() -> void:
	GameState.reset_to_defaults()
	_check(GameState.get_campaign_phase() == GameState.CampaignPhase.COZY_CLEARING \
		and GameState.get_campaign_goal_snapshot().action_id == &"contracts",
		"a fresh campaign starts with one actionable Cozy Clearing objective")
	var opening: Array[String] = []
	for index in range(CampaignProgression.OPENING_ORDER_COUNT):
		opening.append(String(Orders.all()[index].id))
	GameState.apply_save_dict({"completed_orders": opening})
	_check(GameState.get_campaign_phase() == GameState.CampaignPhase.WORKING_YARD \
		and GameState.get_campaign_goal_snapshot().title.contains("Mechanical Splitter"),
		"three opening deliveries hand off cleanly to the Working Yard")
	GameState.apply_save_dict({
		"completed_orders": opening,
		"building_tiers": {String(CompanyStrategy.machine().id): 2},
	})
	_check(GameState.get_campaign_phase() == GameState.CampaignPhase.REGIONAL_COMPANY,
		"the first company-scale machine advances the derived regional phase")
	var mastery: Dictionary = {}
	for species: SpeciesDef in SpeciesTable.all():
		if species.id != EarthCampaign.FINAL_SPECIES_ID:
			mastery[String(species.id)] = M7CContent.mastery().by_species_id(
				species.id).mastery_target
	GameState.apply_save_dict({
		"species_mastery_progress": mastery,
		"infrastructure_projects": ["world_catalogue_archive",
			"heavy_freight_grid", "global_buyer_exchange"],
	})
	_check(GameState.get_campaign_phase() == GameState.CampaignPhase.PLANETARY_MACHINE \
		and GameState.get_campaign_goal_snapshot().target \
			== GameState.TOTAL_EARTH_TREES,
		"terrestrial readiness promotes the exact Earth depletion goal")
	GameState.apply_save_dict({
		"earth_trees_felled": GameState.TOTAL_EARTH_TREES,
		"earth_master": true,
		"earth_finale_state": GameState.EarthFinaleState.COMPLETE,
		"earth_finale_splits": 3,
	})
	_check(GameState.get_campaign_phase() == GameState.CampaignPhase.COSMIC_FINALE \
		and not GameState.is_campaign_complete(),
		"Earth reaching zero opens the Cosmic Finale but does not prematurely roll credits")


func _test_standing_commission_loop() -> void:
	GameState.reset_to_defaults()
	var owned := ["quaking_aspen", "eastern_white_pine", "norway_spruce"]
	GameState.apply_save_dict({
		"completed_orders": ["campfire_warmup", "aspen_hearth_load",
			"pine_campsite_load"],
		"owned_species": owned,
	})
	var cycle_ok := true
	for cycle in range(Orders.standing_commission_limit()):
		var offers := GameState.get_commission_offers()
		cycle_ok = cycle_ok and offers.size() == Orders.COMMISSION_OFFER_COUNT \
			and GameState.has_pending_standing_commission_choice()
		if offers.is_empty():
			break
		var selected: Dictionary = offers[cycle % offers.size()]
		var selected_id := StringName(selected.get("id", &""))
		cycle_ok = cycle_ok and GameState.accept_commission(selected_id)
		var rejected_id := StringName(offers[(cycle + 1) % offers.size()].get("id", &""))
		cycle_ok = cycle_ok and not GameState.accept_commission(rejected_id) \
			and GameState.get_active_commission_ids().size() == 1
		var item_id := StringName(selected.get("required_item", &""))
		var species_id := StringName(selected.get("required_species", &""))
		if item_id == &"":
			var fallback := SpeciesTable.by_id(&"quaking_aspen")
			item_id = fallback.yield_item
			species_id = fallback.id
		var size := (float(selected.get("min_normalized_size", 0.0)) \
			+ float(selected.get("max_normalized_size", 1.0))) * 0.5
		var grade := int(selected.get("minimum_grade", Craftsmanship.Grade.ROUGH))
		for piece in range(int(selected.get("required_count", 0))):
			cycle_ok = cycle_ok and GameState.record_manual_delivery_receipt(
				ManualPieceReceipt.new(item_id, species_id, size, grade,
					StringName("standing_%d_%d" % [cycle, piece])))
		if cycle < Orders.standing_commission_limit() - 1:
			cycle_ok = cycle_ok and not GameState.has_pending_standing_commission_choice()
			_unlock_next_commission_moment(cycle)
	_check(cycle_ok \
		and GameState.get_completed_commission_count() \
			== Orders.standing_commission_limit() \
		and GameState.get_cash() > 0 \
		and GameState.get_standing_commission_cycles_remaining() == 0 \
		and not GameState.has_pending_standing_commission_choice() \
		and GameState.get_active_commission_ids().is_empty(),
		"five auto-paid standing commissions replace repeated board maintenance")
	var cash_after := GameState.get_cash()
	var snapshot := GameState.to_save_dict()
	GameState.reset_to_defaults()
	GameState.apply_save_dict(snapshot)
	_check(GameState.get_cash() == cash_after \
		and GameState.get_standing_commission_cycles_completed() == 5 \
		and not GameState.ensure_commission_offers(),
		"v17 round-trips completed commission rewards without reroll or replay")


func _unlock_next_commission_moment(completed_cycle: int) -> void:
	if completed_cycle == 0:
		EventBus.building_upgraded.emit(CompanyStrategy.machine().id,
			GameState.DEFAULT_BUILDING_TIER + 1)
		return
	if completed_cycle == 1:
		var planetary := GameState.to_save_dict()
		var mastery: Dictionary = {}
		for species: SpeciesDef in SpeciesTable.all():
			if species.id != EarthCampaign.FINAL_SPECIES_ID:
				mastery[String(species.id)] = M7CContent.mastery().by_species_id(
					species.id).mastery_target
		planetary["species_mastery_progress"] = mastery
		planetary["infrastructure_projects"] = ["world_catalogue_archive",
			"heavy_freight_grid", "global_buyer_exchange"]
		GameState.apply_save_dict(planetary)
		return
	if completed_cycle == 2:
		GameState.record_watched_automation_logs(GameState.get_earth_trees_remaining(),
			&"standing_moment_earth_zero", &"quaking_aspen")
		return
	var frontier := GameState.to_save_dict()
	var first := AlienCampaign.traits()[0]
	frontier["arrived_destinations"] = [String(first.destination_id)]
	frontier["alien_destination_states"] = {
		String(first.destination_id): GameState.AlienDestinationState.MASTERED,
	}
	frontier["alien_manual_mastery"] = {
		String(first.id): first.manual_mastery_target,
	}
	GameState.apply_save_dict(frontier)


func _test_hud_focus_and_credits() -> void:
	GameState.reset_to_defaults()
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	var orders_tabs: TabContainer = hud.get_node("OrdersPanel/Column/Tabs")
	var skill_boughs: HBoxContainer = hud.get_node(
		"SkillPanel/Column/SkillBody/BoughScroll/Boughs")
	_check(orders_tabs.is_tab_hidden(1) \
		and hud.get_node_or_null("CampaignGoal") == null \
		and hud.get_node_or_null("SkillPanel/Column/BranchTabs") == null \
		and skill_boughs.get_node_or_null("StrengthTree/Graph") != null \
		and skill_boughs.get_node_or_null("SpeedTree/Graph") != null \
		and skill_boughs.get_node_or_null("MasteryTree/Graph") != null \
		and skill_boughs.get_node_or_null("FrontierTree") == null,
		"the HUD omits the campaign tracker while the skill window shows all three terrestrial trees")
	GameState.campaign_completed.emit()
	await get_tree().process_frame
	var credits: Control = hud.get_node("CreditsPanel")
	_check(credits.visible,
		"campaign completion owns a legible full-screen credits state")
	(hud.get_node("CreditsPanel/CreditsColumn/ContinueButton") as Button).pressed.emit()
	_check(not credits.visible,
		"returning from credits restores the tracker-free yard HUD")
	hud.queue_free()
	await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)
