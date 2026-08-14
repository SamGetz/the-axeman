class_name YardSpeciesRewardDef
extends Resource
## Fixed ordinary-root rewards for one species in one yard.

@export var species_id: StringName = &""
@export_range(1, 1000000000, 1) var cash_reward := 1
@export_range(1, 1000000000, 1) var xp_reward := 1
@export_multiline var tuning_status := \
	"PLACEHOLDER — yard root cash and XP require measured pacing approval"


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if species_id == &"" or SpeciesTable.by_id(species_id) == null:
		errors.append("yard reward references an unknown species:%s" % species_id)
	if cash_reward <= 0 or xp_reward <= 0:
		errors.append("yard species rewards must be positive")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("yard reward tuning must remain explicitly provisional")
	return errors
