class_name YardTimelineEntryDef
extends Resource
## One weighted species window. Overlapping rows form the live delivery roster.

@export var species_id: StringName = &""
@export_range(0.0, 86400.0, 1.0) var start_seconds := 0.0
@export_range(0.0, 86400.0, 1.0) var end_seconds := 1.0
@export_range(0.01, 1000.0, 0.01) var weight := 1.0
@export_multiline var tuning_status := \
	"PLACEHOLDER — yard timeline weighting requires measured pacing approval"


func validate(stage_duration_seconds: float) -> PackedStringArray:
	var errors := PackedStringArray()
	if species_id == &"" or SpeciesTable.by_id(species_id) == null:
		errors.append("yard timeline references an unknown species:%s" % species_id)
	if start_seconds < 0.0 or end_seconds <= start_seconds \
			or end_seconds > stage_duration_seconds:
		errors.append("yard timeline has an invalid time window")
	if weight <= 0.0 or not is_finite(weight):
		errors.append("yard timeline weight must be positive and finite")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("yard timeline tuning must remain explicitly provisional")
	return errors
