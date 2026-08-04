class_name SpeciesMasteryTable
extends Resource

@export var definitions: Array[SpeciesMasteryDef] = []


func by_species_id(id: StringName) -> SpeciesMasteryDef:
	for definition: SpeciesMasteryDef in definitions:
		if definition != null and definition.species_id == id:
			return definition
	return null
