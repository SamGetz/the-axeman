class_name CompanyMachineDef
extends Resource

@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export_range(1, 1000000000, 1) var cost := 1
@export_range(1, 20, 1) var added_dispatch_capacity := 1
@export var tuning_status := "PLACEHOLDER — M10 machine capacity review required"


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or display_name.strip_edges().is_empty() \
			or description.strip_edges().is_empty() or cost <= 0 \
			or added_dispatch_capacity <= 0:
		errors.append("company machine definition is invalid")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("company machine tuning must remain explicitly provisional")
	return errors
