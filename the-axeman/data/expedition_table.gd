class_name ExpeditionTable
extends Resource

@export var expeditions: Array[ExpeditionDef] = []


func by_id(id: StringName) -> ExpeditionDef:
	for expedition: ExpeditionDef in expeditions:
		if expedition != null and expedition.id == id:
			return expedition
	return null


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids: Dictionary = {}
	var species: Dictionary = {}
	for expedition: ExpeditionDef in expeditions:
		if expedition == null:
			errors.append("expedition table contains null")
			continue
		errors.append_array(expedition.validate())
		if ids.has(expedition.id) or species.has(expedition.alien_species_id):
			errors.append("duplicate expedition or alien species:%s" % expedition.id)
		ids[expedition.id] = true
		species[expedition.alien_species_id] = true
	return errors
