extends Node
## Non-headless 1280x720 visual acceptance captures for M9–M14 and generated
## alien surface candidates. This tool changes only in-memory state and never
## touches the player's save file.

const OUT := "/private/tmp/axeman_campaign_"


func _ready() -> void:
	await _capture_hud("cozy_goal", {})
	await _capture_hud("standing_commission_choice", _standing_commission_state())
	await _capture_panel("phased_skills", "SkillsButton", _regional_skill_state())
	await _capture_panel("atlas", "AtlasButton", _earth_company_state())
	await _capture_panel("world_catalogue", "TreesButton", _earth_company_state())
	await _capture_earth_headline()
	await _capture_world("launch_yard", _launch_state())
	await _capture_panel("launch_programme", "AtlasButton", _launch_state(), 520)
	for wood_trait: AlienWoodTraitDef in AlienCampaign.traits():
		await _capture_alien_series(wood_trait)
	await _capture_panel("orbital_company", "AtlasButton", _alien_company_state(), 760)
	await _capture_panel("orbital_company_lower", "AtlasButton", _alien_company_state(), 1120)
	await _capture_credits()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	get_tree().quit()


func _capture_hud(tag: String, state: Dictionary) -> void:
	GameState.apply_save_dict(state)
	var game: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	add_child(game)
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await _frames(24)
	if tag == "standing_commission_choice":
		(hud.get_node("ActiveJobChip/Column/Header/Toggle") as Button).pressed.emit()
		await _frames(3)
	await _save(tag)
	hud.queue_free()
	game.queue_free()
	await _frames(3)


func _capture_credits() -> void:
	GameState.apply_save_dict(_alien_company_state())
	var game: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	add_child(game)
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await _frames(24)
	GameState.campaign_completed.emit()
	await _frames(2)
	await _save("credits")
	hud.queue_free()
	game.queue_free()
	await _frames(3)


func _capture_panel(tag: String, button_name: String, state: Dictionary,
		scroll_position := 0) -> void:
	GameState.apply_save_dict(state)
	var game: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	add_child(game)
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await _frames(24)
	(hud.get_node("QuickMenu/%s" % button_name) as Button).pressed.emit()
	await _frames(4)
	if button_name == "AtlasButton" and scroll_position > 0:
		(hud.get_node("AtlasPanel/Column/Scroll") as ScrollContainer).scroll_vertical \
			= scroll_position
		await _frames(3)
	await _save(tag)
	hud.queue_free()
	game.queue_free()
	await _frames(3)


func _capture_earth_headline() -> void:
	GameState.apply_save_dict(_earth_company_state())
	var game: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	add_child(game)
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await _frames(24)
	hud._show_earth_master_headline()
	await _frames(2)
	await _save("earth_master_headline")
	hud.queue_free()
	game.queue_free()
	await _frames(3)


func _capture_world(tag: String, state: Dictionary) -> void:
	GameState.apply_save_dict(state)
	var game: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	add_child(game)
	await _frames(30)
	await _save(tag)
	game.queue_free()
	await _frames(3)


func _capture_alien_series(wood_trait: AlienWoodTraitDef) -> void:
	var state := _launch_state()
	state["alien_destination_states"] = {
		String(wood_trait.destination_id): GameState.AlienDestinationState.SPECIMEN_READY,
	}
	state["arrived_destinations"] = [String(wood_trait.destination_id)]
	state["selected_species"] = String(wood_trait.id)
	GameState.apply_save_dict(state)
	var game: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	game.debug_split_roll = 0
	add_child(game)
	await _frames(30)
	await _save("%s_fresh" % wood_trait.id)
	var scar_count := 1 if wood_trait.behavior \
		== AlienWoodTraitDef.Behavior.RESONANT_BAND else 2
	if wood_trait.behavior == AlienWoodTraitDef.Behavior.SCAR_PRIMING:
		scar_count = wood_trait.scars_to_prime
	for index in range(scar_count):
		game.debug_swing_world(Plane(Vector3.RIGHT, -0.06 + 0.05 * index))
		await _frames(4)
	await _save("%s_scarred" % wood_trait.id)
	game.debug_slice_world(Plane(Vector3.RIGHT, 0.03))
	await _frames(36)
	await _save("%s_cut" % wood_trait.id)
	game.queue_free()
	await _frames(3)


func _earth_company_state() -> Dictionary:
	var owned: Array[String] = []
	var mastery: Dictionary = {}
	for species: SpeciesDef in SpeciesTable.all():
		owned.append(String(species.id))
		mastery[String(species.id)] = M7CContent.mastery().by_species_id(
			species.id).mastery_target
	var regions: Array[String] = []
	var standing: Dictionary = {}
	var depots: Array[String] = []
	var routes: Dictionary = {}
	for region: RegionDef in RegionalNetwork.regions():
		regions.append(String(region.id))
		standing[String(region.id)] = region.depot_standing_required
		depots.append(String(region.id))
		var route := RegionalNetwork.route_for_region(region.id)
		if route != null:
			routes[String(region.id)] = String(route.id)
	var projects: Array[String] = []
	for project: InfrastructureProjectDef in RegionalNetwork.projects():
		projects.append(String(project.id))
	return {
		"cash": 9999999999,
		"xp": 1000000000,
		"reputation": 99,
		"owned_species": owned,
		"selected_species": "quaking_aspen",
		"species_mastery_progress": mastery,
		"building_tiers": {
			"supplier_ledger": 2,
			"handcart": 2,
			"coffee_thermos": 2,
			"mechanical_splitter": 2,
			"dispatch_console": 2,
			"hydraulic_split_banks": 2,
		},
		"discovered_regions": regions,
		"regional_standing": standing,
		"regional_depots": depots,
		"regional_routes": routes,
		"infrastructure_projects": projects,
		"manual_log_equivalents": 500000,
		"earth_finale_state": GameState.EarthFinaleState.COMPLETE,
		"earth_finale_splits": 3,
		"earth_master": true,
	}


func _standing_commission_state() -> Dictionary:
	return {
		"xp": 500,
		"owned_species": ["quaking_aspen", "eastern_white_pine", "norway_spruce"],
		"completed_orders": ["campfire_warmup", "aspen_hearth_load",
			"pine_campsite_load"],
	}


func _regional_skill_state() -> Dictionary:
	return {
		"xp": 250000,
		"skill_points_earned_total": SkillTree.core_purchase_count(),
		"owned_species": ["quaking_aspen", "eastern_white_pine", "norway_spruce"],
		"completed_orders": ["campfire_warmup", "aspen_hearth_load",
			"pine_campsite_load"],
		"building_tiers": {String(CompanyStrategy.machine().id): 2},
	}


func _launch_state() -> Dictionary:
	var state := _earth_company_state()
	var projects: Array[String] = []
	for project: LaunchProjectDef in LaunchProgram.projects():
		projects.append(String(project.id))
	state["launch_projects"] = projects
	state["spacecraft_loadout"] = {
		SpacecraftComponentDef.Slot.RANGE: "frontier_drive",
		SpacecraftComponentDef.Slot.CARGO: "timber_hold",
		SpacecraftComponentDef.Slot.SHIELDING: "deep_space_shield",
	}
	return state


func _alien_company_state() -> Dictionary:
	var state := _launch_state()
	var destinations: Dictionary = {}
	var mastery: Dictionary = {}
	var fleets: Dictionary = {}
	var lines: Array[String] = []
	for wood_trait: AlienWoodTraitDef in AlienCampaign.traits():
		destinations[String(wood_trait.destination_id)] = GameState.AlienDestinationState.MASTERED
		mastery[String(wood_trait.id)] = wood_trait.manual_mastery_target
		fleets[String(wood_trait.destination_id)] = 2
		lines.append(String(wood_trait.destination_id))
	state["alien_destination_states"] = destinations
	state["arrived_destinations"] = destinations.keys()
	state["alien_manual_mastery"] = mastery
	state["cargo_fleets"] = fleets
	state["orbital_lines"] = lines
	state["expedition_charter"] = "tidal_moon"
	return state


func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _save(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var path := OUT + tag + ".png"
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("SHOT %s (%dx%d, error %d)" % [path, image.get_width(), image.get_height(), error])
