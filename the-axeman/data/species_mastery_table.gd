class_name SpeciesMasteryTable
extends Resource

## Shared authored reward rungs. All species use the same system-building
## placeholders in M8 Slice 1; later tuning may introduce per-species overrides
## only if playtesting demonstrates that one ladder cannot serve the catalogue.
@export var thresholds: Array[SpeciesMasteryThresholdDef] = []
@export var definitions: Array[SpeciesMasteryDef] = []


func by_species_id(id: StringName) -> SpeciesMasteryDef:
	for definition: SpeciesMasteryDef in definitions:
		if definition != null and definition.species_id == id:
			return definition
	return null


func thresholds_for_species(species_id: StringName) -> Array[SpeciesMasteryThresholdDef]:
	var definition := by_species_id(species_id)
	if definition == null or thresholds.is_empty():
		return []
	var positions := [1, maxi(2, int(ceil(float(definition.mastery_target) * 0.5))),
		definition.mastery_target]
	var out: Array[SpeciesMasteryThresholdDef] = []
	for index in range(mini(thresholds.size(), positions.size())):
		var authored: SpeciesMasteryThresholdDef = thresholds[index]
		if authored == null:
			continue
		var scaled := authored.duplicate(true) as SpeciesMasteryThresholdDef
		scaled.required_progress = mini(definition.mastery_target, positions[index])
		out.append(scaled)
	return out


func reached_threshold_count(species_id: StringName, progress: int) -> int:
	var reached := 0
	for threshold: SpeciesMasteryThresholdDef in thresholds_for_species(species_id):
		if threshold != null and progress >= threshold.required_progress:
			reached += 1
	return reached
