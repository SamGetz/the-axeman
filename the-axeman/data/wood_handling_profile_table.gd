class_name WoodHandlingProfileTable
extends Resource

@export var profiles: Array[WoodHandlingProfileDef] = []


func by_species_id(species_id: StringName) -> WoodHandlingProfileDef:
	for profile: WoodHandlingProfileDef in profiles:
		if profile != null and profile.species_ids.has(species_id):
			return profile
	return null


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	if profiles.size() != 5:
		errors.append("handling catalogue must contain exactly five profiles")
	for profile: WoodHandlingProfileDef in profiles:
		if profile == null:
			errors.append("handling catalogue contains null")
			continue
		errors.append_array(profile.validate())
		for species_id: StringName in profile.species_ids:
			if SpeciesTable.by_id(species_id) == null or seen.has(species_id):
				errors.append("unknown or duplicate handling species:%s" % species_id)
			seen[species_id] = true
	if seen.size() != SpeciesTable.count():
		errors.append("every species must belong to one handling profile")
	return errors
