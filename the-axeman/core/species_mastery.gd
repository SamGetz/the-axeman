class_name SpeciesMastery
extends RefCounted
## Read-only mastery effect service. Progress remains owned by GameState and the
## authored reward ladder remains owned by SpeciesMasteryTable; this service is
## the one place that turns reached thresholds into cumulative global effects.


static func total_effect(kind: GameplayModifierDef.Kind) -> float:
	var total := 0.0
	var table := M7CContent.mastery()
	if table == null:
		return total
	for definition: SpeciesMasteryDef in table.definitions:
		if definition == null:
			continue
		total += effect_for_species(definition.species_id, kind)
	return total


static func effect_for_species(species_id: StringName,
		kind: GameplayModifierDef.Kind) -> float:
	var table := M7CContent.mastery()
	if table == null or table.by_species_id(species_id) == null:
		return 0.0
	var progress := GameState.get_species_mastery_progress(species_id)
	var total := 0.0
	for threshold: SpeciesMasteryThresholdDef in table.thresholds:
		if threshold == null or progress < threshold.required_progress:
			continue
		for reward: GameplayModifierDef in threshold.rewards:
			if reward != null and reward.kind == kind \
					and reward.operation == GameplayModifierDef.Operation.ADD:
				total += reward.magnitude
	return total


static func next_threshold(species_id: StringName) -> SpeciesMasteryThresholdDef:
	var table := M7CContent.mastery()
	if table == null or table.by_species_id(species_id) == null:
		return null
	var progress := GameState.get_species_mastery_progress(species_id)
	for threshold: SpeciesMasteryThresholdDef in table.thresholds:
		if threshold != null and progress < threshold.required_progress:
			return threshold
	return null
