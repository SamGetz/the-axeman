class_name LaunchProjectDef
extends Resource

@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export_range(0, 3, 1) var stage := 0
@export_range(1, 10000000000, 1) var cash_cost := 1
@export_range(1, 1000000, 1) var processed_output_required := 1
@export_range(0, 25, 1) var mastery_required := 0
@export var contribution_item_id: StringName = &""
@export_range(0, 1000000, 1) var contribution_amount := 0
@export var tuning_status := "PLACEHOLDER — launch construction tuning review required"


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or display_name.strip_edges().is_empty() \
			or description.strip_edges().is_empty() or cash_cost <= 0 \
			or processed_output_required <= 0 or mastery_required < 0:
		errors.append("launch project identity or requirements are invalid")
	if (contribution_item_id == &"") != (contribution_amount == 0):
		errors.append("launch project contribution identity and amount disagree")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("launch project tuning must remain provisional")
	return errors
