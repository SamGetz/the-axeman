class_name WoodCatalogue
extends RefCounted
## Chopping-only union. EarthCampaign deliberately keeps using SpeciesTable so
## its catalogue remains exactly the authored 25 terrestrial species.


static func all() -> Array[SpeciesDef]:
	var rows: Array[SpeciesDef] = SpeciesTable.all().duplicate()
	for wood_trait: AlienWoodTraitDef in AlienCampaign.traits():
		rows.append(wood_trait.runtime_species())
	return rows


static func count() -> int:
	return SpeciesTable.count() + AlienCampaign.traits().size()


static func at(index: int) -> SpeciesDef:
	var rows := all()
	return null if index < 0 or index >= rows.size() else rows[index]


static func by_id(id: StringName) -> SpeciesDef:
	var earth := SpeciesTable.by_id(id)
	if earth != null:
		return earth
	var wood_trait := AlienCampaign.trait_by_id(id)
	return null if wood_trait == null else wood_trait.runtime_species()


static func index_of(id: StringName) -> int:
	var earth_index := SpeciesTable.index_of(id)
	if earth_index >= 0:
		return earth_index
	for index in range(AlienCampaign.traits().size()):
		if AlienCampaign.traits()[index].id == id:
			return SpeciesTable.count() + index
	return -1
