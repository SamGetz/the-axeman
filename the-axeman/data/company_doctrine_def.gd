class_name CompanyDoctrineDef
extends Resource

enum Effect { CRAFT_VALUE, DISPATCH_CAPACITY, REGIONAL_STANDING }

@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export var effect: Effect = Effect.CRAFT_VALUE
@export var magnitude := 0.0
@export var tuning_status := "PLACEHOLDER — M10 doctrine effects require measured review"


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or display_name.strip_edges().is_empty() \
			or description.strip_edges().is_empty() or magnitude <= 0.0:
		errors.append("doctrine identity, copy or effect is invalid")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("doctrine tuning must remain explicitly provisional")
	return errors
