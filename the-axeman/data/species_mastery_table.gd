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


func reached_threshold_count(progress: int) -> int:
	var reached := 0
	for threshold: SpeciesMasteryThresholdDef in thresholds:
		if threshold != null and progress >= threshold.required_progress:
			reached += 1
	return reached
