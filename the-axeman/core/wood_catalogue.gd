class_name WoodCatalogue
extends RefCounted
## Survival-era catalogue: the 25 terrestrial species only.

static func all() -> Array[SpeciesDef]:
	return SpeciesTable.all()

static func count() -> int:
	return SpeciesTable.count()

static func at(index: int) -> SpeciesDef:
	return SpeciesTable.at(index)

static func by_id(id: StringName) -> SpeciesDef:
	return SpeciesTable.by_id(id)

static func index_of(id: StringName) -> int:
	return SpeciesTable.index_of(id)
