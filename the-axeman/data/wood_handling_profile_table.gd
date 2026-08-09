class_name WoodHandlingProfileTable
extends Resource

@export var profiles: Array[WoodHandlingProfileDef] = []


func by_species_id(species_id: StringName) -> WoodHandlingProfileDef:
	for profile: WoodHandlingProfileDef in profiles:
		if profile != null and profile.species_ids.has(species_id):
			return profile
	return null
