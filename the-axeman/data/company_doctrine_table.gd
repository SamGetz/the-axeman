class_name CompanyDoctrineTable
extends Resource

@export var doctrines: Array[CompanyDoctrineDef] = []


func by_id(id: StringName) -> CompanyDoctrineDef:
	for doctrine: CompanyDoctrineDef in doctrines:
		if doctrine != null and doctrine.id == id:
			return doctrine
	return null
