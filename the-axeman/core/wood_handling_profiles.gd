class_name WoodHandlingProfiles
extends RefCounted

const TABLE_PATH := "res://data/wood_handling_profile_table.tres"
static var _table: WoodHandlingProfileTable


static func all() -> Array[WoodHandlingProfileDef]:
	var table := _catalogue()
	return [] if table == null else table.profiles.duplicate()


static func profile_for_species(species_id: StringName) -> WoodHandlingProfileDef:
	var table := _catalogue()
	return null if table == null else table.by_species_id(species_id)


static func validate_catalogue() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	if all().size() != 5:
		errors.append("terrestrial handling catalogue must contain exactly five profiles")
	for profile: WoodHandlingProfileDef in all():
		if profile == null:
			errors.append("null handling profile")
			continue
		errors.append_array(profile.validate())
		for species_id: StringName in profile.species_ids:
			if SpeciesTable.by_id(species_id) == null or seen.has(species_id):
				errors.append("unknown or duplicate handling species:%s" % species_id)
			seen[species_id] = true
	if seen.size() != SpeciesTable.count():
		errors.append("every terrestrial species must belong to one handling profile")
	return errors


static func _catalogue() -> WoodHandlingProfileTable:
	if _table == null:
		_table = load(TABLE_PATH) as WoodHandlingProfileTable
	return _table
