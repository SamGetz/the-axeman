class_name EarthCampaign
extends RefCounted

const FINAL_SPECIES_ID := &"lignum_vitae"
const GLOBAL_PROJECT_IDS: Array[StringName] = [
	&"world_catalogue_archive",
	&"heavy_freight_grid",
	&"global_buyer_exchange",
]


static func catalogue_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for species: SpeciesDef in SpeciesTable.all():
		var region := RegionalNetwork.region_for_species(species.id)
		var contract := Orders.by_id(StringName("%s_delivery" % species.id))
		var profile := MechanicalSplitter.profile_for_species(species.id)
		rows.append({
			"species_id": species.id,
			"owned": GameState.owns_species(species.id),
			"manual_mastery": GameState.is_species_mastered(species.id),
			"certified": GameState.is_species_mastered(species.id),
			"supplier": &"" if region == null else region.id,
			"contract_complete": contract != null and GameState.has_completed_order(contract.id),
			"automation": profile != null and MechanicalSplitter.has_installed_profile(species.id),
		})
	return rows


static func next_anti_stall_goal() -> Dictionary:
	for species: SpeciesDef in SpeciesTable.all():
		if species.id == FINAL_SPECIES_ID:
			continue
		if not GameState.owns_species(species.id):
			return {"kind": "own", "species_id": species.id,
				"text": "Acquire %s" % species.display_name}
		if not GameState.is_species_mastered(species.id):
			return {"kind": "master", "species_id": species.id,
				"text": "Master %s by hand" % species.display_name}
	for project_id: StringName in GLOBAL_PROJECT_IDS:
		if not GameState.has_infrastructure_project(project_id):
			var project := RegionalNetwork.project_by_id(project_id)
			return {"kind": "project", "project_id": project_id,
				"text": "Complete %s" % project.display_name}
	if not GameState.owns_species(FINAL_SPECIES_ID):
		return {"kind": "own", "species_id": FINAL_SPECIES_ID,
			"text": "Acquire the Lignum Vitae showcase log"}
	if GameState.is_earth_master():
		return {"kind": "launch", "text": "Begin the launch programme"}
	if GameState.get_earth_finale_state() == GameState.EarthFinaleState.COMPLETE:
		return {"kind": "depletion", "text": "%s trees remain on Earth" % \
			GameState.get_earth_trees_remaining()}
	return {"kind": "finale", "species_id": FINAL_SPECIES_ID,
		"text": "Deliver Lignum Vitae to the original block"}


static func terrestrial_requirements_complete() -> bool:
	for species: SpeciesDef in SpeciesTable.all():
		if species.id != FINAL_SPECIES_ID and not GameState.is_species_mastered(species.id):
			return false
	for project_id: StringName in GLOBAL_PROJECT_IDS:
		if not GameState.has_infrastructure_project(project_id):
			return false
	return true
