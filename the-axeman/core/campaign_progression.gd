class_name CampaignProgression
extends RefCounted
## One derived campaign spine. It introduces no parallel progression state: all
## gates are projections of authoritative GameState/catalogue facts.

const OPENING_ORDER_COUNT := 3


static func phase() -> GameState.CampaignPhase:
	if GameState.is_campaign_complete():
		return GameState.CampaignPhase.COMPLETE
	if GameState.is_earth_depleted():
		return GameState.CampaignPhase.COSMIC_FINALE
	if EarthCampaign.terrestrial_requirements_complete():
		return GameState.CampaignPhase.PLANETARY_MACHINE
	if GameState.get_regional_route_count() > 0 \
			or Shop.get_level(CompanyStrategy.machine().id) > 0:
		return GameState.CampaignPhase.REGIONAL_COMPANY
	if opening_orders_complete():
		return GameState.CampaignPhase.WORKING_YARD
	return GameState.CampaignPhase.COZY_CLEARING


static func opening_orders_complete() -> bool:
	var orders := Orders.all()
	for index in range(mini(OPENING_ORDER_COUNT, orders.size())):
		var order: OrderDef = orders[index]
		if order == null or not GameState.has_completed_order(order.id):
			return false
	return orders.size() >= OPENING_ORDER_COUNT


static func goal_snapshot() -> CampaignGoalSnapshot:
	var current_phase := phase()
	match current_phase:
		GameState.CampaignPhase.COZY_CLEARING:
			return _opening_goal(current_phase)
		GameState.CampaignPhase.WORKING_YARD:
			return _working_yard_goal(current_phase)
		GameState.CampaignPhase.REGIONAL_COMPANY:
			return _earth_growth_goal(current_phase)
		GameState.CampaignPhase.PLANETARY_MACHINE:
			return CampaignGoalSnapshot.new(current_phase, "Finish Earth",
				"Scale the company until every one of Earth's 3.04 trillion trees is accounted for.",
				GameState.get_earth_trees_felled(), GameState.TOTAL_EARTH_TREES,
				&"company")
		GameState.CampaignPhase.COSMIC_FINALE:
			return _frontier_goal(current_phase)
	return CampaignGoalSnapshot.new(current_phase, "The ledger is closed",
		"Earth is empty. Three alien lines are running. Somehow, this counts as growth.",
		1, 1, &"credits")


static func phase_name(value: GameState.CampaignPhase) -> String:
	match value:
		GameState.CampaignPhase.COZY_CLEARING:
			return "Cozy Clearing"
		GameState.CampaignPhase.WORKING_YARD:
			return "Working Yard"
		GameState.CampaignPhase.REGIONAL_COMPANY:
			return "Regional Company"
		GameState.CampaignPhase.PLANETARY_MACHINE:
			return "Planetary Machine"
		GameState.CampaignPhase.COSMIC_FINALE:
			return "Cosmic Finale"
	return "Complete"


static func _opening_goal(current_phase: GameState.CampaignPhase) -> CampaignGoalSnapshot:
	var orders := Orders.all()
	for index in range(mini(OPENING_ORDER_COUNT, orders.size())):
		var order: OrderDef = orders[index]
		if order == null or GameState.has_completed_order(order.id):
			continue
		var current := GameState.get_active_order_progress_for(order.id)
		return CampaignGoalSnapshot.new(current_phase, order.title,
			"Complete the opening delivery and learn the full yard loop.",
			current, order.required_count, &"contracts")
	return CampaignGoalSnapshot.new(current_phase, "Learn the yard",
		"Chop, process, sell, and improve the block.", 0, 0, &"chop")


static func _working_yard_goal(current_phase: GameState.CampaignPhase) -> CampaignGoalSnapshot:
	if not MechanicalSplitter.is_installed():
		return CampaignGoalSnapshot.new(current_phase, "Build the Mechanical Splitter",
			"Turn mastered wood into watched production without giving up the block.",
			0, 0, &"shop")
	var next := GameState.get_next_unowned_species()
	if next != null:
		return CampaignGoalSnapshot.new(current_phase, "Expand the wood catalogue",
			"Acquire and manually master %s." % next.display_name,
			GameState.get_mastered_species_count(), SpeciesTable.count(), &"trees")
	return CampaignGoalSnapshot.new(current_phase, "Establish a regional route",
		"Connect the yard to its first dependable supplier network.",
		GameState.get_regional_route_count(), 1, &"atlas")


static func _earth_growth_goal(current_phase: GameState.CampaignPhase) -> CampaignGoalSnapshot:
	var next := EarthCampaign.next_anti_stall_goal()
	return CampaignGoalSnapshot.new(current_phase, "Grow the company",
		String(next.get("text", "Complete the terrestrial catalogue.")),
		GameState.get_mastered_species_count(), SpeciesTable.count(),
		StringName(next.get("kind", &"trees")))


static func _frontier_goal(current_phase: GameState.CampaignPhase) -> CampaignGoalSnapshot:
	if not GameState.has_launch_project(&"deep_space_vessel"):
		return CampaignGoalSnapshot.new(current_phase, "Build the deep-space vessel",
			"Earth is empty. Use the continuity reserve to finish the launch programme.",
			GameState.get_launch_project_count(), LaunchProgram.projects().size(), &"launch")
	var mastered := 0
	for wood_trait: AlienWoodTraitDef in AlienCampaign.traits():
		if GameState.get_alien_destination_state(wood_trait.destination_id) \
				== GameState.AlienDestinationState.MASTERED:
			mastered += 1
	if mastered < AlienCampaign.traits().size():
		return CampaignGoalSnapshot.new(current_phase, "Master alien timber",
			"Complete first contact and manual mastery at all three destinations.",
			mastered, AlienCampaign.traits().size(), &"expedition")
	if GameState.get_orbital_line_count() < AlienCampaign.traits().size():
		return CampaignGoalSnapshot.new(current_phase, "Build three orbital lines",
			"Give each mastered alien wood its own production line.",
			GameState.get_orbital_line_count(), AlienCampaign.traits().size(), &"alien_company")
	if SkillTree.get_level(&"frontier_master") <= 0:
		return CampaignGoalSnapshot.new(current_phase, "Become Frontier Master",
			"Spend the nine points earned from alien mastery to finish the Frontier tree.",
			SkillTree.frontier_purchases_owned(), SkillTree.frontier_purchase_count(), &"skills")
	return CampaignGoalSnapshot.new(current_phase, "Close the first orbital ledger",
		"Run one receipt containing output from all three orbital lines.",
		1 if GameState.has_combined_orbital_receipt() else 0, 1, &"alien_company")
