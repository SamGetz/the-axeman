class_name InfrastructureProjectDef
extends Resource

@export var id: StringName = &""
@export var region_id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export_range(1, 1000000000, 1) var cash_cost := 1
@export_range(1, 1000000, 1) var processed_output_required := 1
@export var tuning_status := "PLACEHOLDER — infrastructure contribution review required"


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or display_name.strip_edges().is_empty() \
			or description.strip_edges().is_empty() or cash_cost <= 0 \
			or processed_output_required <= 0:
		errors.append("infrastructure project identity or requirements are invalid")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("infrastructure tuning must remain explicitly provisional")
	return errors
