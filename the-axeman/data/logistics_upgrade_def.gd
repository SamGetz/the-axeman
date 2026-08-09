class_name LogisticsUpgradeDef
extends Resource

@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export var required_previous_id: StringName = &""
@export_range(1, 1000000000, 1) var cost := 1
@export var tuning_status := "PLACEHOLDER — M8 logistics purchase tuning required"


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or display_name.strip_edges().is_empty() \
			or description.strip_edges().is_empty() or cost <= 0:
		errors.append("logistics upgrade identity, copy or cost is invalid")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("logistics purchase tuning must remain explicitly provisional")
	return errors
