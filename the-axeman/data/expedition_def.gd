class_name ExpeditionDef
extends Resource

@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export var alien_species_id: StringName = &""
@export_range(1, 10, 1) var range_required := 1
@export_range(1, 10, 1) var shielding_required := 1
@export_range(1, 8640000, 1) var flight_seconds := 1
@export var tuning_status := "PLACEHOLDER — expedition timing and requirements review required"


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or display_name.strip_edges().is_empty() \
			or description.strip_edges().is_empty() or alien_species_id == &"" \
			or range_required <= 0 or shielding_required <= 0 or flight_seconds <= 0:
		errors.append("expedition identity or requirements are invalid")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("expedition tuning must remain provisional")
	return errors
